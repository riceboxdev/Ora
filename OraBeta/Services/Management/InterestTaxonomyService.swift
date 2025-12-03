//
//  InterestTaxonomyService.swift
//  OraBeta
//
//  Service for managing the interest taxonomy hierarchy
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class InterestTaxonomyService {
    private let db = Firestore.firestore()
    private let interestsCollection = "interests"
    
    static let shared = InterestTaxonomyService()
    
    private var taxonomyCache: [String: Interest]?
    private var lastCacheTime: Date?
    private let cacheDuration: TimeInterval = 3600
    
    private init() {}
    
    // MARK: - Cache Management
    
    private func shouldRefreshCache() -> Bool {
        guard let lastTime = lastCacheTime else { return true }
        return Date().timeIntervalSince(lastTime) > cacheDuration
    }
    
    func clearCache() {
        taxonomyCache = nil
        lastCacheTime = nil
    }
    
    // MARK: - Fetch Operations
    
    /// Get a single interest by ID
    func getInterest(id: String) async throws -> Interest {
        if let cached = taxonomyCache?[id] {
            return cached
        }
        
        let docRef = db.collection(interestsCollection).document(id)
        let document = try await docRef.getDocument()
        
        guard let interest = try Interest.from(document: document) else {
            throw NSError(domain: "InterestTaxonomyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Interest not found"])
        }
        
        return interest
    }
    
    /// Get all interests (cached in memory)
    func getAllInterests() async throws -> [Interest] {
        if let cached = taxonomyCache, !shouldRefreshCache() {
            return Array(cached.values)
        }
        
        let query = db.collection(interestsCollection).whereField("isActive", isEqualTo: true)
        let snapshot = try await query.getDocuments()
        
        var interests: [String: Interest] = [:]
        for document in snapshot.documents {
            if let interest = try Interest.from(document: document) {
                interests[interest.id] = interest
            }
        }
        
        taxonomyCache = interests
        lastCacheTime = Date()
        
        return Array(interests.values)
    }
    
    /// Get the interest taxonomy tree with optional depth limit
    func getInterestTree(maxDepth: Int? = nil) async throws -> [Interest] {
        let allInterests = try await getAllInterests()
        
        let rootInterests = allInterests.filter { $0.parentId == nil }
        
        guard let maxDepth = maxDepth else {
            return rootInterests.sorted { $0.name < $1.name }
        }
        
        return rootInterests
            .filter { $0.level <= maxDepth }
            .sorted { $0.name < $1.name }
    }
    
    /// Get all children of a parent interest
    func getChildInterests(parentId: String) async throws -> [Interest] {
        let allInterests = try await getAllInterests()
        return allInterests
            .filter { $0.parentId == parentId }
            .sorted { $0.name < $1.name }
    }
    
    /// Get the full path from root to an interest (breadcrumbs)
    func getInterestPath(interestId: String) async throws -> [Interest] {
        var path: [Interest] = []
        var currentId: String? = interestId
        let allInterests = try await getAllInterests()
        let interestMap = Dictionary(uniqueKeysWithValues: allInterests.map { ($0.id, $0) })
        
        while let id = currentId, let interest = interestMap[id] {
            path.insert(interest, at: 0)
            currentId = interest.parentId
        }
        
        return path
    }
    
    /// Search interests by keyword or name
    func searchInterests(query: String, limit: Int = 20) async throws -> [Interest] {
        let allInterests = try await getAllInterests()
        let lowerQuery = query.lowercased()
        
        let results = allInterests.filter { interest in
            let nameMatch = interest.name.lowercased().contains(lowerQuery)
            let displayMatch = interest.displayName.lowercased().contains(lowerQuery)
            let keywordMatch = interest.keywords.contains { $0.lowercased().contains(lowerQuery) }
            let synonymMatch = interest.synonyms.contains { $0.lowercased().contains(lowerQuery) }
            
            return nameMatch || displayMatch || keywordMatch || synonymMatch
        }
        
        return Array(results
            .sorted { $0.name < $1.name }
            .prefix(limit))
    }
    
    /// Get related interests (by ID or by relationship)
    func getRelatedInterests(interestId: String, limit: Int = 10) async throws -> [Interest] {
        let interest = try await getInterest(id: interestId)
        let allInterests = try await getAllInterests()
        let interestMap = Dictionary(uniqueKeysWithValues: allInterests.map { ($0.id, $0) })
        
        var related: [Interest] = []
        
        for relatedId in interest.relatedInterestIds {
            if let relatedInterest = interestMap[relatedId] {
                related.append(relatedInterest)
            }
        }
        
        for otherInterest in allInterests where related.count < limit {
            if interest.level == otherInterest.level && interest.parentId == otherInterest.parentId && otherInterest.id != interestId {
                if !related.contains(where: { $0.id == otherInterest.id }) {
                    related.append(otherInterest)
                }
            }
        }
        
        return Array(related.prefix(limit))
    }
    
    /// Get top-level (root) interests
    func getTopLevelInterests() async throws -> [Interest] {
        let allInterests = try await getAllInterests()
        return allInterests
            .filter { $0.parentId == nil }
            .sorted { $0.name < $1.name }
    }
    
    // MARK: - Write Operations (Admin)
    
    /// Create a new interest
    func createInterest(
        name: String,
        displayName: String,
        parentId: String? = nil,
        description: String? = nil,
        keywords: [String] = [],
        synonyms: [String] = []
    ) async throws -> Interest {
        let id = UUID().uuidString.lowercased()
        
        var path: [String] = []
        var level = 0
        
        if let parentId = parentId {
            let parent = try await getInterest(id: parentId)
            path = parent.path + [parent.name]
            level = parent.level + 1
        }
        
        let interest = Interest(
            id: id,
            name: name,
            displayName: displayName,
            parentId: parentId,
            level: level,
            path: path,
            description: description,
            keywords: keywords,
            synonyms: synonyms
        )
        
        try await db.collection(interestsCollection).document(id).setData(interest.toFirestoreData())
        clearCache()
        
        return interest
    }
    
    /// Update an existing interest
    func updateInterest(
        id: String,
        displayName: String? = nil,
        description: String? = nil,
        keywords: [String]? = nil,
        synonyms: [String]? = nil,
        relatedInterestIds: [String]? = nil,
        isActive: Bool? = nil
    ) async throws -> Interest {
        var updates: [String: Any] = ["updatedAt": Timestamp(date: Date())]
        
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        
        if let description = description {
            updates["description"] = description
        }
        
        if let keywords = keywords {
            updates["keywords"] = keywords
        }
        
        if let synonyms = synonyms {
            updates["synonyms"] = synonyms
        }
        
        if let relatedInterestIds = relatedInterestIds {
            updates["relatedInterestIds"] = relatedInterestIds
        }
        
        if let isActive = isActive {
            updates["isActive"] = isActive
        }
        
        try await db.collection(interestsCollection).document(id).updateData(updates)
        clearCache()
        
        return try await getInterest(id: id)
    }
    
    /// Delete an interest (soft delete by deactivating)
    func deactivateInterest(id: String) async throws {
        try await db.collection(interestsCollection).document(id).updateData([
            "isActive": false,
            "updatedAt": Timestamp(date: Date())
        ])
        clearCache()
    }
}
