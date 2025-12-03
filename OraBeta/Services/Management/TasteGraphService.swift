//
//  TasteGraphService.swift
//  OraBeta
//
//  Service for managing user taste graphs and interest affinities
//  Based on Pinterest's Taste Graph architecture
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TasteGraphService {
    private let db = Firestore.firestore()
    private let tasteGraphsCollection = "user_taste_graphs"
    
    static let shared = TasteGraphService()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Get user's taste graph
    /// - Parameter userId: User ID
    /// - Returns: UserTasteGraph
    func getUserTasteGraph(userId: String) async throws -> UserTasteGraph {
        let docRef = db.collection(tasteGraphsCollection).document(userId)
        let document = try await docRef.getDocument()
        
        if let graph = try UserTasteGraph.from(document: document) {
            return graph
        }
        
        // Return empty graph if not found
        return UserTasteGraph(userId: userId)
    }
    
    /// Get suggested interests for a user based on their taste graph
    /// - Parameters:
    ///   - userId: User ID
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of suggested interests
    func getSuggestedInterests(userId: String, limit: Int = 10) async throws -> [Interest] {
        let graph = try await getUserTasteGraph(userId: userId)
        let topAffinities = graph.topInterests(count: limit * 2) // Get more to filter
        
        var suggestions: [Interest] = []
        var seenIds = Set<String>()
        
        // 1. Add top affinity interests themselves
        for affinity in topAffinities {
            if let interest = try? await InterestTaxonomyService.shared.getInterest(id: affinity.interestId) {
                if !seenIds.contains(interest.id) {
                    suggestions.append(interest)
                    seenIds.insert(interest.id)
                }
            }
        }
        
        // 2. Add related interests (collaborative filtering lite)
        // For each top interest, get its related interests
        for affinity in topAffinities.prefix(5) {
            if let related = try? await InterestTaxonomyService.shared.getRelatedInterests(interestId: affinity.interestId, limit: 3) {
                for interest in related {
                    if !seenIds.contains(interest.id) {
                        suggestions.append(interest)
                        seenIds.insert(interest.id)
                    }
                }
            }
        }
        
        return Array(suggestions.prefix(limit))
    }
    
    // MARK: - Update Operations
    
    /// Update affinity from explicit follow
    /// - Parameters:
    ///   - userId: User ID
    ///   - interestId: Interest ID being followed
    func updateAffinityFromFollow(userId: String, interestId: String) async throws {
        try await updateAffinity(
            userId: userId,
            interestId: interestId,
            source: .explicitFollow,
            weight: 1.0
        )
    }
    
    /// Update affinity from save action
    /// - Parameters:
    ///   - userId: User ID
    ///   - post: Post being saved
    func updateAffinityFromSave(userId: String, post: Post) async throws {
        // Use classified interests if available
        if let interestIds = post.interestIds, !interestIds.isEmpty {
            for interestId in interestIds {
                // Use confidence as weight modifier if available
                let confidence = post.interestScores?[interestId] ?? 1.0
                try await updateAffinity(
                    userId: userId,
                    interestId: interestId,
                    source: .inferredFromSaves,
                    weight: 0.8 * confidence
                )
            }
        }
        // Fallback to tags if no classification
        else if let tags = post.tags {
            // Try to match tags to interests (simplified)
            // In a real system, we'd use the taxonomy service to map tags to IDs
            // For now, we skip this to avoid complex tag matching logic here
        }
    }
    
    /// Update affinity from view action
    /// - Parameters:
    ///   - userId: User ID
    ///   - post: Post being viewed
    ///   - duration: View duration in seconds
    func updateAffinityFromView(userId: String, post: Post, duration: TimeInterval) async throws {
        // Only count significant views (> 3 seconds)
        guard duration > 3.0 else { return }
        
        // Cap duration impact (e.g., max 30 seconds)
        let effectiveDuration = min(duration, 30.0)
        let durationWeight = effectiveDuration / 30.0 // 0.1 to 1.0
        
        if let interestIds = post.interestIds, !interestIds.isEmpty {
            for interestId in interestIds {
                let confidence = post.interestScores?[interestId] ?? 1.0
                try await updateAffinity(
                    userId: userId,
                    interestId: interestId,
                    source: .inferredFromViews,
                    weight: 0.4 * durationWeight * confidence
                )
            }
        }
    }
    
    /// Update affinity from search
    /// - Parameters:
    ///   - userId: User ID
    ///   - query: Search query
    ///   - interestId: Matched interest ID (if any)
    func updateAffinityFromSearch(userId: String, query: String, interestId: String) async throws {
        try await updateAffinity(
            userId: userId,
            interestId: interestId,
            source: .inferredFromSearch,
            weight: 0.6
        )
    }
    
    // MARK: - Core Update Logic
    
    /// Core method to update a single affinity
    private func updateAffinity(
        userId: String,
        interestId: String,
        source: UserTasteGraph.InterestAffinity.AffinitySource,
        weight: Double
    ) async throws {
        let docRef = db.collection(tasteGraphsCollection).document(userId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var graph: UserTasteGraph
            if document.exists {
                if let existingGraph = try? UserTasteGraph.from(document: document) {
                    graph = existingGraph
                } else {
                    graph = UserTasteGraph(userId: userId)
                }
            } else {
                graph = UserTasteGraph(userId: userId)
            }
            
            // Find existing affinity or create new
            var affinities = graph.interests
            var affinity: UserTasteGraph.InterestAffinity
            
            if let index = affinities.firstIndex(where: { $0.interestId == interestId }) {
                let existing = affinities[index]
                
                // Calculate new score
                // Score increases with engagement, but capped at 1.0
                // New Score = Old Score + (Weight * (1 - Old Score))
                // This ensures it asymptotically approaches 1.0
                let newScore = min(existing.score + (weight * 0.1 * (1.0 - existing.score)), 1.0)
                
                affinity = UserTasteGraph.InterestAffinity(
                    interestId: interestId,
                    score: newScore,
                    source: source, // Update source to most recent interaction type
                    engagementCount: existing.engagementCount + 1,
                    firstEngagement: existing.firstEngagement,
                    lastEngagement: Date(),
                    decayFactor: existing.decayFactor
                )
                affinities[index] = affinity
            } else {
                // New affinity
                affinity = UserTasteGraph.InterestAffinity(
                    interestId: interestId,
                    score: min(weight * 0.5, 1.0), // Initial score
                    source: source,
                    engagementCount: 1,
                    firstEngagement: Date(),
                    lastEngagement: Date(),
                    decayFactor: 0.01
                )
                affinities.append(affinity)
            }
            
            // Update graph
            let updatedGraph = UserTasteGraph(
                userId: userId,
                interests: affinities,
                lastUpdated: Date(),
                version: graph.version
            )
            
            transaction.setData(updatedGraph.toFirestoreData(), forDocument: docRef)
            return nil
        }
    }
}
