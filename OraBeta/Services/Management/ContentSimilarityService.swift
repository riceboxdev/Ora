//
//  ContentSimilarityService.swift
//  OraBeta
//
//  Service for finding similar content (PinSage-inspired)
//

import Foundation
import FirebaseFirestore

@MainActor
class ContentSimilarityService {
    private let db = Firestore.firestore()
    
    static let shared = ContentSimilarityService()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get similar posts (Pinterest's "Related Pins")
    /// - Parameters:
    ///   - postId: Source post ID
    ///   - limit: Maximum results
    /// - Returns: Array of similar posts
    func getSimilarPosts(to postId: String, limit: Int = 20) async throws -> [Post] {
        // 1. Get source post
        let postDoc = try await db.collection("posts").document(postId).getDocument()
        guard let post = await Post.from(firestoreData: postDoc.data() ?? [:], documentId: postId, profiles: [:]) else {
            return []
        }
        
        // 2. Get candidates based on primary interest
        var candidates: [Post] = []
        
        if let interestId = post.primaryInterestId {
            // Fetch posts with same primary interest
            let snapshot = try await db.collection("posts")
                .whereField("primaryInterestId", isEqualTo: interestId)
                .limit(to: limit * 2) // Fetch more for re-ranking
                .getDocuments()
            
            for doc in snapshot.documents {
                if doc.documentID != postId { // Exclude source post
                    if let candidate = await Post.from(firestoreData: doc.data(), documentId: doc.documentID, profiles: [:]) {
                        candidates.append(candidate)
                    }
                }
            }
        } else if let tags = post.tags, !tags.isEmpty {
            // Fallback to tags
            let snapshot = try await db.collection("posts")
                .whereField("tags", arrayContainsAny: Array(tags.prefix(10)))
                .limit(to: limit * 2)
                .getDocuments()
            
            for doc in snapshot.documents {
                if doc.documentID != postId {
                    if let candidate = await Post.from(firestoreData: doc.data(), documentId: doc.documentID, profiles: [:]) {
                        candidates.append(candidate)
                    }
                }
            }
        }
        
        // 3. Rank candidates by similarity score
        var scoredCandidates: [(post: Post, score: Double)] = []
        
        for candidate in candidates {
            let score = await calculateSimilarity(post1: post, post2: candidate)
            scoredCandidates.append((candidate, score))
        }
        
        // 4. Return top N
        return scoredCandidates
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.post }
    }
    
    /// Get posts from similar interests
    /// - Parameters:
    ///   - interestId: Source interest ID
    ///   - limit: Maximum results
    /// - Returns: Array of posts
    func getPostsFromSimilarInterests(to interestId: String, limit: Int = 30) async throws -> [Post] {
        // 1. Get related interests
        let relatedInterests = try await InterestTaxonomyService.shared.getRelatedInterests(interestId: interestId, limit: 5)
        let relatedIds = relatedInterests.map { $0.id }
        
        guard !relatedIds.isEmpty else { return [] }
        
        // 2. Fetch posts for these interests
        // Note: Firestore 'in' query limit is 10
        let snapshot = try await db.collection("posts")
            .whereField("primaryInterestId", in: Array(relatedIds.prefix(10)))
            .limit(to: limit)
            .getDocuments()
        
        var posts: [Post] = []
        for doc in snapshot.documents {
            if let post = await Post.from(firestoreData: doc.data(), documentId: doc.documentID, profiles: [:]) {
                posts.append(post)
            }
        }
        
        return posts.shuffled() // Shuffle for discovery
    }
    
    /// Calculate similarity score between two posts
    /// - Parameters:
    ///   - post1: First post
    ///   - post2: Second post
    /// - Returns: Similarity score (0.0 to 1.0)
    func calculateSimilarity(post1: Post, post2: Post) async -> Double {
        // 1. Interest Overlap (50%)
        let interestScore = calculateInterestOverlap(post1: post1, post2: post2)
        
        // 2. Tag Overlap (30%)
        let tagScore = calculateTagOverlap(post1: post1, post2: post2)
        
        // 3. Visual Similarity (10%) - Placeholder
        let visualScore = 0.0
        
        // 4. User Overlap (10%) - Placeholder (saved by same users)
        let userScore = 0.0
        
        return (interestScore * 0.50) +
               (tagScore * 0.30) +
               (visualScore * 0.10) +
               (userScore * 0.10)
    }
    
    // MARK: - Helper Methods
    
    private func calculateInterestOverlap(post1: Post, post2: Post) -> Double {
        guard let ids1 = post1.interestIds, let ids2 = post2.interestIds else {
            return 0.0
        }
        
        let set1 = Set(ids1)
        let set2 = Set(ids2)
        let intersection = set1.intersection(set2)
        
        if intersection.isEmpty { return 0.0 }
        
        // Jaccard index
        return Double(intersection.count) / Double(set1.union(set2).count)
    }
    
    private func calculateTagOverlap(post1: Post, post2: Post) -> Double {
        guard let tags1 = post1.tags, let tags2 = post2.tags else {
            return 0.0
        }
        
        let set1 = Set(tags1.map { $0.lowercased() })
        let set2 = Set(tags2.map { $0.lowercased() })
        let intersection = set1.intersection(set2)
        
        if intersection.isEmpty { return 0.0 }
        
        return Double(intersection.count) / Double(set1.union(set2).count)
    }
    
    // Placeholder for future implementation
    private func getCoOccurringPosts(postId: String) async throws -> [String] {
        return []
    }
}
