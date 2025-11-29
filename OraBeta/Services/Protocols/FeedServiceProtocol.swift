//
//  FeedServiceProtocol.swift
//  OraBeta
//
//  Protocol for FeedService to enable testability and dependency injection
//

import Foundation
import FirebaseFirestore

/// Protocol defining the interface for feed operations
@MainActor
protocol FeedServiceProtocol {
    /// Get discover feed with ranking strategy
    /// - Parameters:
    ///   - userId: Current user ID (for personalized ranking if needed)
    ///   - limit: Maximum number of posts to return
    ///   - strategy: Ranking strategy to use (only applied on initial load or refresh, not on pagination)
    ///   - lastDocument: Last document for pagination (optional)
    ///   - applyRanking: Whether to apply ranking strategy (default: true, set to false for pagination to maintain order)
    /// - Returns: Array of posts (ranked if applyRanking is true, otherwise in Firestore order)
    func getDiscoverFeed(
        userId: String?,
        limit: Int,
        strategy: RankingStrategy,
        lastDocument: QueryDocumentSnapshot?,
        applyRanking: Bool
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?)
    
    /// Get home feed with posts from followed users and topics
    /// - Parameters:
    ///   - userId: Current user ID (required)
    ///   - limit: Maximum number of posts to return
    ///   - lastDocument: Last document for pagination (optional)
    /// - Returns: Array of posts, last document for pagination, and whether user has follows
    func getHomeFeed(
        userId: String,
        limit: Int,
        lastDocument: QueryDocumentSnapshot?
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?, hasFollows: Bool)
}

