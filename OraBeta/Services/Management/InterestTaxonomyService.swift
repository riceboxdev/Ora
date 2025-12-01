//
//  InterestTaxonomyService.swift
//  OraBeta
//
//  Service for managing the hierarchical interest taxonomy
//  Based on Pinterest's Interest Taxonomy architecture
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum InterestSource {
    case trendingTags
    case boardNames
    case searchQueries
    case userAnnotations
}

@MainActor
class InterestTaxonomyService {
    private let db = Firestore.firestore()
    private let interestsCollection = "interests"
    
    static let shared = InterestTaxonomyService()
    
    // In-memory cache
    private var cachedInterests: [Interest] = []
    private var lastCacheUpdate: Date?
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetch entire interest tree (cached)
    /// - Parameters:
    ///   - maxDepth: Optional maximum depth to fetch
    ///   - forceRefresh: Force refresh cache
    /// - Returns: Array of all interests
    func getInterestTree(maxDepth: Int? = nil, forceRefresh: Bool = false) async throws -> [Interest] {
        // Check cache
        if !forceRefresh,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheExpirationInterval,
           !cachedInterests.isEmpty {
            Logger.info("📊 Returning cached interest tree (\(cachedInterests.count) interests)", service: "InterestTaxonomyService")
            
            if let maxDepth = maxDepth {
                return cachedInterests.filter { $0.level <= maxDepth }
            }
            return cachedInterests
        }
        
        // Fetch from Firestore
        Logger.info("🔄 Fetching interest tree from Firestore", service: "InterestTaxonomyService")
        
        var query: Query = db.collection(interestsCollection)
            .whereField("isActive", isEqualTo: true)
        
        if let maxDepth = maxDepth {
            query = query.whereField("level", isLessThanOrEqualTo: maxDepth)
        }
        
        let snapshot = try await query.getDocuments()
        
        var interests: [Interest] = []
        for document in snapshot.documents {
            if let interest = try? Interest.from(document: document) {
                interests.append(interest)
            }
        }
        
        // Update cache
        if maxDepth == nil {
            cachedInterests = interests
            lastCacheUpdate = Date()
        }
        
        Logger.info("✅ Fetched \(interests.count) interests", service: "InterestTaxonomyService")
        return interests
    }
    
    /// Get direct children of a parent interest
    /// - Parameter parentId: Parent interest ID (nil for root interests)
    /// - Returns: Array of child interests
    func getChildInterests(parentId: String?) async throws -> [Interest] {
        let query: Query
        if let parentId = parentId {
            query = db.collection(interestsCollection)
                .whereField("parentId", isEqualTo: parentId)
                .whereField("isActive", isEqualTo: true)
        } else {
            query = db.collection(interestsCollection)
                .whereField("level", isEqualTo: 0)
                .whereField("isActive", isEqualTo: true)
        }
        
        let snapshot = try await query.getDocuments()
        
        var interests: [Interest] = []
        for document in snapshot.documents {
            if let interest = try? Interest.from(document: document) {
                interests.append(interest)
            }
        }
        
        return interests.sorted { $0.displayName < $1.displayName }
    }
    
    /// Get full path from root to interest (breadcrumbs)
    /// - Parameter interestId: Interest ID
    /// - Returns: Array of interests from root to target
    func getInterestPath(interestId: String) async throws -> [Interest] {
        let interest = try await getInterest(id: interestId)
        var path: [Interest] = [interest]
        
        var currentParentId = interest.parentId
        while let parentId = currentParentId {
            let parent = try await getInterest(id: parentId)
            path.insert(parent, at: 0)
            currentParentId = parent.parentId
        }
        
        return path
    }
    
    /// Get a single interest by ID
    /// - Parameter id: Interest ID
    /// - Returns: Interest or nil
    func getInterest(id: String) async throws -> Interest {
        // Check cache first
        if let cached = cachedInterests.first(where: { $0.id == id }) {
            return cached
        }
        
        // Fetch from Firestore
        let document = try await db.collection(interestsCollection).document(id).getDocument()
        
        guard let interest = try Interest.from(document: document) else {
            throw InterestError.notFound
        }
        
        return interest
    }
    
    /// Get top-level (root) interests
    /// - Returns: Array of root interests
    func getTopLevelInterests() async throws -> [Interest] {
        return try await getChildInterests(parentId: nil)
    }
    
    // MARK: - Search
    
    /// Search interests by keyword
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum results
    /// - Returns: Array of matching interests
    func searchInterests(query: String, limit: Int = 20) async throws -> [Interest] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedQuery.isEmpty else {
            return []
        }
        
        // Fetch all interests (use cache)
        let allInterests = try await getInterestTree()
        
        // Search in name, keywords, synonyms
        let matches = allInterests.filter { interest in
            // Match name
            if interest.name.contains(normalizedQuery) || interest.displayName.lowercased().contains(normalizedQuery) {
                return true
            }
            
            // Match keywords
            if interest.keywords.contains(where: { $0.lowercased().contains(normalizedQuery) }) {
                return true
            }
            
            // Match synonyms
            if interest.synonyms.contains(where: { $0.lowercased().contains(normalizedQuery) }) {
                return true
            }
            
            return false
        }
        
        // Sort by relevance (exact matches first, then by level)
        let sorted = matches.sorted { a, b in
            let aExact = a.name == normalizedQuery || a.displayName.lowercased() == normalizedQuery
            let bExact = b.name == normalizedQuery || b.displayName.lowercased() == normalizedQuery
            
            if aExact != bExact {
                return aExact
            }
            
            // Prefer lower levels (more specific)
            return a.level > b.level
        }
        
        return Array(sorted.prefix(limit))
    }
    
    /// Get related interests (siblings, related IDs)
    /// - Parameters:
    ///   - interestId: Interest ID
    ///   - limit: Maximum results
    /// - Returns: Array of related interests  
    func getRelatedInterests(interestId: String, limit: Int = 10) async throws -> [Interest] {
        let interest = try await getInterest(id: interestId)
        var related: [Interest] = []
        
        // Get explicitly related interests
        for relatedId in interest.relatedInterestIds.prefix(limit) {
            if let relatedInterest = try? await getInterest(id: relatedId) {
                related.append(relatedInterest)
            }
        }
        
        // If not enough, add siblings
        if related.count < limit, let parentId = interest.parentId {
            let siblings = try await getChildInterests(parentId: parentId)
            for sibling in siblings where sibling.id != interestId {
                related.append(sibling)
                if related.count >= limit {
                    break
                }
            }
        }
        
        return Array(related.prefix(limit))
    }
    
    // MARK: - Create/Update Operations
    
    /// Create a new interest
    /// - Parameter interest: Interest to create
    func createInterest(_ interest: Interest) async throws {
        let data = interest.toFirestoreData()
        try await db.collection(interestsCollection).document(interest.id).setData(data)
        
        // Invalidate cache
        lastCacheUpdate = nil
        
        Logger.info("✅ Created interest: \(interest.displayName)", service: "InterestTaxonomyService")
    }
    
    /// Update an existing interest
    /// - Parameter interest: Interest to update
    func updateInterest(_ interest: Interest) async throws {
        var updatedInterest = interest
        // Force update timestamp
        updatedInterest = Interest(
            id: interest.id,
            name: interest.name,
            displayName: interest.displayName,
            parentId: interest.parentId,
            level: interest.level,
            path: interest.path,
            description: interest.description,
            coverImageUrl: interest.coverImageUrl,
            isActive: interest.isActive,
            createdAt: interest.createdAt,
            updatedAt: Date(),
            postCount: interest.postCount,
            followerCount: interest.followerCount,
            weeklyGrowth: interest.weeklyGrowth,
            monthlyGrowth: interest.monthlyGrowth,
            relatedInterestIds: interest.relatedInterestIds,
            keywords: interest.keywords,
            synonyms: interest.synonyms
        )
        
        let data = updatedInterest.toFirestoreData()
        try await db.collection(interestsCollection).document(interest.id).setData(data, merge: true)
        
        // Invalidate cache
        lastCacheUpdate = nil
        
        Logger.info("✅ Updated interest: \(interest.displayName)", service: "InterestTaxonomyService")
    }
    
    /// Increment post count for interest
    /// - Parameter interestId: Interest ID
    func incrementPostCount(interestId: String) async throws {
        try await db.collection(interestsCollection).document(interestId).updateData([
            "postCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Invalidate cache
        lastCacheUpdate = nil
    }
    
    /// Increment follower count for interest
    /// - Parameter interestId: Interest ID
    func incrementFollowerCount(interestId: String) async throws {
        try await db.collection(interestsCollection).document(interestId).updateData([
            "followerCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Invalidate cache
        lastCacheUpdate = nil
    }
    
    /// Decrement follower count for interest
    /// - Parameter interestId: Interest ID
    func decrementFollowerCount(interestId: String) async throws {
        try await db.collection(interestsCollection).document(interestId).updateData([
            "followerCount": FieldValue.increment(Int64(-1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Invalidate cache
        lastCacheUpdate = nil
    }
    
    // MARK: - Admin Operations
    
    /// Batch create interests (for seeding)
    /// - Parameter interests: Array of interests to create
    func batchCreateInterests(_ interests: [Interest]) async throws {
        let batch = db.batch()
        
        for interest in interests {
            let ref = db.collection(interestsCollection).document(interest.id)
            batch.setData(interest.toFirestoreData(), forDocument: ref)
        }
        
        try await batch.commit()
        
        // Invalidate cache
        lastCacheUpdate = nil
        
        Logger.info("✅ Batch created \(interests.count) interests", service: "InterestTaxonomyService")
    }
    
    // MARK: - Interest Mining (Future)
    
    /// Mine new interest candidates from various sources
    /// This is a placeholder for future ML-powered interest discovery
    /// - Parameter source: Source to mine from
    /// - Returns: Array of interest candidates
    func mineNewInterests(from source: InterestSource) async throws -> [Interest.Candidate] {
        // TODO: Implement interest mining
        // - Analyze trending tags
        // - Extract from board names
        // - Mine from search queries
        // - Use NLP to identify concepts
        return []
    }
}

// MARK: - Errors

enum InterestError: LocalizedError {
    case notFound
    case invalidHierarchy
    case creationFailed
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Interest not found"
        case .invalidHierarchy:
            return "Invalid interest hierarchy"
        case .creationFailed:
            return "Failed to create interest"
        }
    }
}
