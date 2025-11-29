//
//  CommentService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CommentService {
    private let db = Firestore.firestore()
    private let blockedUsersService: BlockedUsersService
    
    init(blockedUsersService: BlockedUsersService? = nil) {
        self.blockedUsersService = blockedUsersService ?? BlockedUsersService()
    }
    
    /// Add a comment to a post
    func addComment(postId: String, text: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CommentError.notAuthenticated
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentError.invalidComment
        }
        
        // Create comment document with auto-generated ID
        let commentRef = db.collection("comments").document()
        let commentId = commentRef.documentID
        
        try await commentRef.setData([
            "postId": postId,
            "userId": userId,
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update post comment count (non-blocking)
        Task {
            do {
                try await updatePostCommentCount(postId: postId)
            } catch {
                print("⚠️ CommentService: Failed to update post comment count: \(error.localizedDescription)")
            }
        }
        
        // Update user preferences (non-blocking)
        Task {
            do {
                let preferenceService = UserPreferenceService()
                try await preferenceService.updatePreferencesFromEngagement(
                    postId: postId,
                    engagementType: .comment
                )
            } catch {
                print("⚠️ CommentService: Failed to update preferences: \(error.localizedDescription)")
            }
        }
        
        print("✅ CommentService: Successfully added comment to post \(postId)")
        return commentId
    }
    
    /// Update a comment
    func updateComment(commentId: String, text: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CommentError.notAuthenticated
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentError.invalidComment
        }
        
        // Verify ownership
        let commentDoc = try await db.collection("comments").document(commentId).getDocument()
        guard let data = commentDoc.data(),
              let commentUserId = data["userId"] as? String,
              commentUserId == userId else {
            throw CommentError.unauthorized
        }
        
        // Update comment
        try await db.collection("comments").document(commentId).updateData([
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ CommentService: Successfully updated comment \(commentId)")
    }
    
    /// Delete a comment
    func deleteComment(commentId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CommentError.notAuthenticated
        }
        
        // Verify ownership
        let commentDoc = try await db.collection("comments").document(commentId).getDocument()
        guard let data = commentDoc.data(),
              let commentUserId = data["userId"] as? String,
              let postId = data["postId"] as? String,
              commentUserId == userId else {
            throw CommentError.unauthorized
        }
        
        // Delete comment
        try await db.collection("comments").document(commentId).delete()
        
        // Update post comment count (non-blocking)
        Task {
            do {
                try await updatePostCommentCount(postId: postId)
            } catch {
                print("⚠️ CommentService: Failed to update post comment count: \(error.localizedDescription)")
            }
        }
        
        print("✅ CommentService: Successfully deleted comment \(commentId)")
    }
    
    /// Update post comment count by counting comments
    private func updatePostCommentCount(postId: String) async throws {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        let commentCount = snapshot.documents.count
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "commentCount": commentCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ CommentService: Updated comment count for post \(postId): \(commentCount)")
    }
    
    /// Get comments for a post
    func getComments(postId: String, limit: Int = 50, postAuthorId: String? = nil) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        let comments = snapshot.documents.compactMap { doc -> Comment? in
            let data = doc.data()
            guard
                  let userId = data["userId"] as? String,
                  let text = data["text"] as? String,
                  let postId = data["postId"] as? String else {
                return nil
            }
            
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return Comment(
                id: doc.documentID,
                postId: postId,
                userId: userId,
                text: text,
                createdAt: createdAt
            )
        }
        
        // Filter out comments from blocked users and comments on posts from blocked users
        do {
            let blockedUserIds = try await blockedUsersService.getAllBlockedUserIds()
            let beforeCount = comments.count
            
            // If post author is provided and is blocked, hide all comments on that post
            if let postAuthorId = postAuthorId, blockedUserIds.contains(postAuthorId) {
                print("✅ CommentService: Post author is blocked, hiding all \(comments.count) comments")
                return []
            }
            
            // Filter out comments from blocked users
            let filteredComments = comments.filter { comment in
                !blockedUserIds.contains(comment.userId)
            }
            
            let filteredCount = beforeCount - filteredComments.count
            if filteredCount > 0 {
                print("✅ CommentService: Filtered out \(filteredCount) comment(s) from blocked users")
            }
            
            return filteredComments
        } catch {
            print("⚠️ CommentService: Failed to get blocked users, showing all comments: \(error.localizedDescription)")
            return comments
        }
    }
    
    /// Get comment count for a post
    func getCommentCount(postId: String) async throws -> Int {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        return snapshot.documents.count
    }
}

struct Comment: Identifiable {
    let id: String
    let postId: String
    let userId: String
    let text: String
    let createdAt: Date
}

enum CommentError: LocalizedError {
    case notAuthenticated
    case invalidComment
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidComment:
            return "Comment text cannot be empty"
        case .unauthorized:
            return "Unauthorized to perform this action"
        }
    }
}

