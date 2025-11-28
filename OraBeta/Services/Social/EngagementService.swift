//
//  EngagementService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import UIKit

@MainActor
class EngagementService {
    private let likeService: LikeService
    private let commentService: CommentService
    private let boardService: BoardService
    
    init(likeService: LikeService? = nil, commentService: CommentService? = nil, boardService: BoardService? = nil) {
        self.likeService = likeService ?? LikeService()
        self.commentService = commentService ?? CommentService()
        self.boardService = boardService ?? BoardService()
    }
    
    /// Comment on a post
    func commentOnPost(postId: String, text: String) async throws {
        _ = try await commentService.addComment(postId: postId, text: text)
    }
    
    /// Get comments for a post
    func getComments(postId: String) async throws -> [Comment] {
        return try await commentService.getComments(postId: postId)
    }
    
    /// Get like count for a post
    func getLikeCount(postId: String) async throws -> Int {
        return try await likeService.getLikeCount(postId: postId)
    }
    
    /// Get comment count for a post
    func getCommentCount(postId: String) async throws -> Int {
        return try await commentService.getCommentCount(postId: postId)
    }
    
    /// Check if current user has liked a post
    func hasLiked(postId: String) async throws -> (liked: Bool, likeId: String?) {
        return try await likeService.hasLiked(postId: postId)
    }
    
    /// Like a post
    func likePost(postId: String) async throws -> String {
        return try await likeService.likePost(postId: postId)
    }
    
    /// Unlike a post
    func unlikePost(postId: String) async throws {
        try await likeService.unlikePost(postId: postId)
    }
    
    /// Save post to board
    func savePostToBoard(postId: String, boardId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EngagementError.notAuthenticated
        }
        
        try await boardService.savePostToBoard(postId: postId, boardId: boardId, userId: userId)
    }
    
    /// Share post
    func sharePost(_ post: Post) -> UIActivityViewController {
        var items: [Any] = []
        
        if let url = URL(string: post.imageUrl) {
            items.append(url)
        }
        
        if let caption = post.caption {
            items.append(caption)
        }
        
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    /// Repost to user feed or board (TODO: Implement)
    func repost(post: Post, toBoardId: String? = nil) async throws {
        // TODO: Implement
    }
}

enum EngagementError: LocalizedError {
    case notAuthenticated
    case invalidComment
    case commentFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidComment:
            return "Comment text cannot be empty"
        case .commentFailed:
            return "Failed to add comment"
        }
    }
}

