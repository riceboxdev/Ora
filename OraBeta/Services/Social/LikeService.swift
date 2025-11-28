//
//  LikeService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class LikeService {
    private let db = Firestore.firestore()
    
    init() {
        // Register service with logging system
        _ = LoggingServiceRegistry.shared.register(serviceName: "LikeService")
        Logger.info("Initializing", service: "LikeService")
    }
    
    /// Like a post
    func likePost(postId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LikeError.notAuthenticated
        }
        
        Logger.debug("Liking post \(postId)", service: "LikeService")
        Logger.debug("   User ID: \(userId)", service: "LikeService")
        
        // Check if already liked
        let likeId = "\(postId)_\(userId)"
        let likeDoc = try await db.collection("likes").document(likeId).getDocument()
        
        if likeDoc.exists {
            Logger.info("Already liked post \(postId)", service: "LikeService")
            return likeId
        }
        
        // Create like document
        try await db.collection("likes").document(likeId).setData([
            "postId": postId,
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        // Update post like count (non-blocking)
        Task {
            do {
                try await updatePostLikeCount(postId: postId)
            } catch {
                Logger.warning("Failed to update post like count: \(error.localizedDescription)", service: "LikeService")
            }
        }
        
        // Update user preferences (non-blocking)
        Task {
            do {
                let preferenceService = UserPreferenceService()
                try await preferenceService.updatePreferencesFromEngagement(
                    postId: postId,
                    engagementType: .like
                )
            } catch {
                Logger.warning("Failed to update preferences: \(error.localizedDescription)", service: "LikeService")
            }
        }
        
        Logger.info("Successfully liked post \(postId)", service: "LikeService")
        return likeId
    }
    
    /// Unlike a post
    func unlikePost(postId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw LikeError.notAuthenticated
        }
        
        Logger.debug("Unliking post \(postId)", service: "LikeService")
        Logger.debug("   User ID: \(userId)", service: "LikeService")
        
        let likeId = "\(postId)_\(userId)"
        let likeDoc = try await db.collection("likes").document(likeId).getDocument()
        
        guard likeDoc.exists else {
            Logger.info("Post \(postId) not liked", service: "LikeService")
            return
        }
        
        // Delete like document
        try await db.collection("likes").document(likeId).delete()
        
        // Update post like count (non-blocking)
        Task {
            do {
                try await updatePostLikeCount(postId: postId)
            } catch {
                Logger.warning("Failed to update post like count: \(error.localizedDescription)", service: "LikeService")
            }
        }
        
        Logger.info("Successfully unliked post \(postId)", service: "LikeService")
    }
    
    /// Update post like count by counting likes
    private func updatePostLikeCount(postId: String) async throws {
        Logger.debug("Updating like count for post \(postId)", service: "LikeService")
        
        let snapshot = try await db.collection("likes")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        let likeCount = snapshot.documents.count
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "likeCount": likeCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        Logger.info("Updated like count for post \(postId): \(likeCount)", service: "LikeService")
    }
    
    /// Check if current user has liked a post
    func hasLiked(postId: String) async throws -> (liked: Bool, likeId: String?) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return (false, nil)
        }
        
        let likeId = "\(postId)_\(userId)"
        let likeDoc = try await db.collection("likes").document(likeId).getDocument()
        
        return (likeDoc.exists, likeDoc.exists ? likeId : nil)
    }
    
    /// Get like count for a post
    func getLikeCount(postId: String) async throws -> Int {
        let snapshot = try await db.collection("likes")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    /// Get all likes for a post (with user info)
    func getLikes(postId: String, limit: Int = 50) async throws -> [Like] {
        let snapshot = try await db.collection("likes")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> Like? in
            guard let data = doc.data() as? [String: Any],
                  let userId = data["userId"] as? String,
                  let postId = data["postId"] as? String else {
                return nil
            }
            
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return Like(
                id: doc.documentID,
                postId: postId,
                userId: userId,
                createdAt: createdAt
            )
        }
    }
}

struct Like: Identifiable {
    let id: String
    let postId: String
    let userId: String
    let createdAt: Date
}

enum LikeError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        }
    }
}

