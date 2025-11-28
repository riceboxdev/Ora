//
//  FeedAnalyticsService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedAnalyticsService {
    private let db = Firestore.firestore()
    
    init() {
        // Register service with logging system
        _ = LoggingServiceRegistry.shared.register(serviceName: "FeedAnalyticsService")
        Logger.info("Initializing", service: "FeedAnalyticsService")
    }
    
    /// Track a view interaction for a post
    /// - Parameters:
    ///   - postId: The post ID being viewed
    ///   - userId: The user ID viewing the post (optional, will use current user if nil)
    ///   - duration: Time spent viewing the post in seconds
    ///   - position: Position of the post in the feed (optional)
    func trackView(postId: String, userId: String?, duration: TimeInterval? = nil, position: Int? = nil) async throws {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot track view - no user ID", service: "FeedAnalyticsService")
            return
        }
        
        // Create interaction document
        let interactionId = "\(postId)_\(currentUserId)_view_\(UUID().uuidString)"
        let interactionRef = db.collection("post_interactions").document(interactionId)
        
        var data: [String: Any] = [
            "postId": postId,
            "userId": currentUserId,
            "interactionType": "view",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        if let duration = duration {
            data["duration"] = duration
        }
        
        if let position = position {
            data["position"] = position
        }
        
        try await interactionRef.setData(data)
        
        // Update post view count (non-blocking, can fail without breaking the app)
        Task {
            do {
                try await updatePostViewCount(postId: postId)
            } catch {
                Logger.warning("Failed to update post view count: \(error.localizedDescription)", service: "FeedAnalyticsService")
            }
        }
        
        // Update user preferences (non-blocking)
        Task {
            do {
                let preferenceService = UserPreferenceService()
                try await preferenceService.updatePreferencesFromEngagement(
                    postId: postId,
                    engagementType: .view,
                    duration: duration
                )
            } catch {
                Logger.warning("Failed to update preferences: \(error.localizedDescription)", service: "FeedAnalyticsService")
            }
        }
        
        Logger.info("Tracked view for post \(postId)", service: "FeedAnalyticsService")
        Logger.debug("   User ID: \(currentUserId)", service: "FeedAnalyticsService")
        if let duration = duration {
            Logger.debug("   Duration: \(String(format: "%.2f", duration))s", service: "FeedAnalyticsService")
        }
        if let position = position {
            Logger.debug("   Position: \(position)", service: "FeedAnalyticsService")
        }
    }
    
    /// Track a click interaction for a post
    /// - Parameters:
    ///   - postId: The post ID being clicked
    ///   - userId: The user ID clicking the post (optional, will use current user if nil)
    ///   - clickType: Type of click (e.g., "profile", "hashtag", "link")
    func trackClick(postId: String, userId: String?, clickType: String) async throws {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot track click - no user ID", service: "FeedAnalyticsService")
            return
        }
        
        Logger.debug("Tracking click for post \(postId)", service: "FeedAnalyticsService")
        Logger.debug("   Click type: \(clickType)", service: "FeedAnalyticsService")
        Logger.debug("   User ID: \(currentUserId)", service: "FeedAnalyticsService")
        
        let interactionId = "\(postId)_\(currentUserId)_click_\(UUID().uuidString)"
        let interactionRef = db.collection("post_interactions").document(interactionId)
        
        try await interactionRef.setData([
            "postId": postId,
            "userId": currentUserId,
            "interactionType": "click",
            "clickType": clickType,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        Logger.info("Tracked click for post \(postId), type: \(clickType)", service: "FeedAnalyticsService")
    }
    
    /// Track a share interaction for a post
    /// - Parameters:
    ///   - postId: The post ID being shared
    ///   - userId: The user ID sharing the post (optional, will use current user if nil)
    ///   - shareType: Type of share (e.g., "external", "internal")
    func trackShare(postId: String, userId: String?, shareType: String) async throws {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot track share - no user ID", service: "FeedAnalyticsService")
            return
        }
        
        Logger.debug("Tracking share for post \(postId)", service: "FeedAnalyticsService")
        Logger.debug("   Share type: \(shareType)", service: "FeedAnalyticsService")
        Logger.debug("   User ID: \(currentUserId)", service: "FeedAnalyticsService")
        
        let interactionId = "\(postId)_\(currentUserId)_share_\(UUID().uuidString)"
        let interactionRef = db.collection("post_interactions").document(interactionId)
        
        try await interactionRef.setData([
            "postId": postId,
            "userId": currentUserId,
            "interactionType": "share",
            "shareType": shareType,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        // Update post share count (non-blocking)
        Task {
            do {
                try await updatePostShareCount(postId: postId)
            } catch {
                Logger.warning("Failed to update post share count: \(error.localizedDescription)", service: "FeedAnalyticsService")
            }
        }
        
        // Update user preferences (non-blocking)
        Task {
            do {
                let preferenceService = UserPreferenceService()
                try await preferenceService.updatePreferencesFromEngagement(
                    postId: postId,
                    engagementType: .share
                )
            } catch {
                Logger.warning("Failed to update preferences: \(error.localizedDescription)", service: "FeedAnalyticsService")
            }
        }
        
        Logger.info("Tracked share for post \(postId), type: \(shareType)", service: "FeedAnalyticsService")
    }
    
    // MARK: - Private Methods
    
    /// Update post view count by counting interactions
    private func updatePostViewCount(postId: String) async throws {
        Logger.debug("Updating view count for post \(postId)", service: "FeedAnalyticsService")
        
        let snapshot = try await db.collection("post_interactions")
            .whereField("postId", isEqualTo: postId)
            .whereField("interactionType", isEqualTo: "view")
            .getDocuments()
        
        let viewCount = snapshot.documents.count
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "viewCount": viewCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        Logger.info("Updated view count for post \(postId): \(viewCount)", service: "FeedAnalyticsService")
    }
    
    /// Update post share count by counting interactions
    private func updatePostShareCount(postId: String) async throws {
        Logger.debug("Updating share count for post \(postId)", service: "FeedAnalyticsService")
        
        let snapshot = try await db.collection("post_interactions")
            .whereField("postId", isEqualTo: postId)
            .whereField("interactionType", isEqualTo: "share")
            .getDocuments()
        
        let shareCount = snapshot.documents.count
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "shareCount": shareCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        Logger.info("Updated share count for post \(postId): \(shareCount)", service: "FeedAnalyticsService")
    }
}

