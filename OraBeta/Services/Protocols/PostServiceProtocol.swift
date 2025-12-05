//
//  PostServiceProtocol.swift
//  OraBeta
//
//  Protocol for PostService to enable testability and dependency injection
//

import Foundation
import FirebaseFirestore

/// Protocol defining the interface for post management operations
@MainActor
protocol PostServiceProtocol {
    /// Create a new post - saves to Firestore via Firebase Function
    func createPost(
        userId: String,
        imageUrl: String,
        thumbnailUrl: String?,
        imageWidth: Int?,
        imageHeight: Int?,
        caption: String?,
        interestIds: [String]?
    ) async throws -> String
    
    /// Edit a post - updates Firestore via Firebase Function
    /// Only the post owner can edit their posts
    func editPost(
        postId: String,
        caption: String?,
        interestIds: [String]?
    ) async throws
    
    /// Get posts from Firestore
    /// - Parameters:
    ///   - userId: Optional user ID to filter posts by user (for user profile)
    ///   - limit: Maximum number of posts to return
    ///   - lastDocument: Last document for pagination (optional)
    /// - Returns: Array of posts
    func getPosts(
        userId: String?,
        limit: Int,
        lastDocument: QueryDocumentSnapshot?
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?)
    
    /// Delete a post - removes from Firestore via Firebase Function
    /// Only the post owner can delete their posts
    func deletePost(postId: String) async throws
}

