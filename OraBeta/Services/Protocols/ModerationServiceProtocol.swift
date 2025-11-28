//
//  ModerationServiceProtocol.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation

/// Protocol for moderation service to enable testing and dependency injection
@MainActor
protocol ModerationServiceProtocol {
    // MARK: - Rule Management
    
    /// Register a new moderation rule
    /// - Parameter rule: The rule to register
    func registerRule(_ rule: ModerationRule)
    
    // MARK: - Evaluation
    
    /// Evaluate a post against all registered rules
    /// - Parameter post: The post to evaluate
    /// - Returns: The final moderation status
    func evaluatePost(_ post: Post) async throws -> ModerationStatus
    
    /// Evaluate content before post creation
    /// - Parameters:
    ///   - imageUrl: URL of the image
    ///   - caption: Optional caption
    ///   - tags: Optional tags
    /// - Returns: The moderation status
    func evaluateContent(imageUrl: String, caption: String?, tags: [String]?) async throws -> ModerationStatus
    
    // MARK: - Admin Actions
    
    /// Approve a post
    /// - Parameters:
    ///   - postId: ID of the post to approve
    ///   - moderatorId: ID of the moderator
    ///   - notes: Optional notes
    func approvePost(postId: String, moderatorId: String, notes: String?) async throws
    
    /// Reject a post
    /// - Parameters:
    ///   - postId: ID of the post to reject
    ///   - moderatorId: ID of the moderator
    ///   - reason: Reason for rejection
    ///   - notes: Optional additional notes
    func rejectPost(postId: String, moderatorId: String, reason: String, notes: String?) async throws
    
    /// Flag a post for review
    /// - Parameters:
    ///   - postId: ID of the post to flag
    ///   - moderatorId: ID of the moderator
    ///   - reason: Reason for flagging
    ///   - notes: Optional additional notes
    func flagPost(postId: String, moderatorId: String, reason: String, notes: String?) async throws
    
    // MARK: - Queries
    
    /// Get moderation history for a post
    /// - Parameter postId: ID of the post
    /// - Returns: Array of moderation actions
    func getModerationHistory(postId: String) async throws -> [ModerationAction]
    
    /// Get posts pending moderation
    /// - Parameter limit: Maximum number of posts to return
    /// - Returns: Array of posts awaiting review
    func getPendingPosts(limit: Int) async throws -> [Post]
    
    /// Get flagged posts
    /// - Parameter limit: Maximum number of posts to return
    /// - Returns: Array of flagged posts
    func getFlaggedPosts(limit: Int) async throws -> [Post]
}
