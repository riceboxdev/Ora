//
//  ModerationService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation
import FirebaseFirestore

@MainActor
class ModerationService: ModerationServiceProtocol {
    private let db = Firestore.firestore()
    private let profileService: ProfileService
    
    // Registered moderation rules, sorted by priority (highest first)
    private var rules: [ModerationRule] = []
    
    init(profileService: ProfileService) {
        self.profileService = profileService
    }
    
    // MARK: - Rule Management
    
    func registerRule(_ rule: ModerationRule) {
        Logger.info("Registering moderation rule: \(rule.name) (priority: \(rule.priority))", service: "ModerationService")
        rules.append(rule)
        // Sort by priority (highest first)
        rules.sort { $0.priority > $1.priority }
    }
    
    // MARK: - Evaluation
    
    func evaluatePost(_ post: Post) async throws -> ModerationStatus {
        Logger.info("Evaluating post: \(post.id)", service: "ModerationService")
        Logger.debug("Running \(rules.count) moderation rules", service: "ModerationService")
        
        var finalStatus: ModerationStatus = .approved
        var finalReason: String?
        var finalMetadata: [String: String]?
        
        // Execute rules in priority order
        for rule in rules {
            Logger.debug("Executing rule: \(rule.name)", service: "ModerationService")
            
            do {
                let result = try await rule.evaluate(post: post)
                
                Logger.debug("Rule \(rule.name) returned: \(result.status)", service: "ModerationService")
                
                // Update status based on rule result
                finalStatus = result.status
                finalReason = result.reason
                finalMetadata = result.metadata
                
                // Stop evaluation if rule says so
                if !result.shouldContinueEvaluation {
                    Logger.info("Rule \(rule.name) stopped evaluation", service: "ModerationService")
                    break
                }
            } catch {
                Logger.error("Rule \(rule.name) failed: \(error.localizedDescription)", service: "ModerationService")
                // Continue with other rules on error
            }
        }
        
        Logger.info("Final moderation status for post \(post.id): \(finalStatus)", service: "ModerationService")
        return finalStatus
    }
    
    func evaluateContent(imageUrl: String, caption: String?, interestIds: [String]?) async throws -> ModerationStatus {
        Logger.info("Evaluating content before post creation", service: "ModerationService")
        
        // Create a temporary post for evaluation
        let tempPost = Post(
            activityId: "temp_\(UUID().uuidString)",
            userId: "temp",
            imageUrl: imageUrl,
            caption: caption,
            interestIds: interestIds
        )
        
        return try await evaluatePost(tempPost)
    }
    
    // MARK: - Admin Actions
    
    func approvePost(postId: String, moderatorId: String, notes: String?) async throws {
        Logger.info("Approving post: \(postId) by moderator: \(moderatorId)", service: "ModerationService")
        
        // Update post in Firestore
        try await db.collection("posts").document(postId).updateData([
            "moderationStatus": ModerationStatus.approved.rawValue,
            "moderatedAt": Timestamp(date: Date()),
            "moderatedBy": moderatorId
        ])
        
        // Create moderation action for audit trail
        try await createModerationAction(
            postId: postId,
            moderatorUserId: moderatorId,
            action: .approved,
            reason: nil,
            notes: notes,
            ruleName: "Manual Review"
        )
        
        Logger.info("Post \(postId) approved successfully", service: "ModerationService")
    }
    
    func rejectPost(postId: String, moderatorId: String, reason: String, notes: String?) async throws {
        Logger.info("Rejecting post: \(postId) by moderator: \(moderatorId)", service: "ModerationService")
        
        // Update post in Firestore
        try await db.collection("posts").document(postId).updateData([
            "moderationStatus": ModerationStatus.rejected.rawValue,
            "moderatedAt": Timestamp(date: Date()),
            "moderatedBy": moderatorId,
            "moderationReason": reason
        ])
        
        // Create moderation action for audit trail
        try await createModerationAction(
            postId: postId,
            moderatorUserId: moderatorId,
            action: .rejected,
            reason: reason,
            notes: notes,
            ruleName: "Manual Review"
        )
        
        Logger.info("Post \(postId) rejected successfully", service: "ModerationService")
    }
    
    func flagPost(postId: String, moderatorId: String, reason: String, notes: String?) async throws {
        Logger.info("Flagging post: \(postId) by moderator: \(moderatorId)", service: "ModerationService")
        
        // Update post in Firestore
        try await db.collection("posts").document(postId).updateData([
            "moderationStatus": ModerationStatus.flagged.rawValue,
            "moderatedAt": Timestamp(date: Date()),
            "moderatedBy": moderatorId,
            "moderationReason": reason
        ])
        
        // Create moderation action for audit trail
        try await createModerationAction(
            postId: postId,
            moderatorUserId: moderatorId,
            action: .flagged,
            reason: reason,
            notes: notes,
            ruleName: "Manual Review"
        )
        
        Logger.info("Post \(postId) flagged successfully", service: "ModerationService")
    }
    
    // MARK: - Queries
    
    func getModerationHistory(postId: String) async throws -> [ModerationAction] {
        Logger.info("Getting moderation history for post: \(postId)", service: "ModerationService")
        
        let snapshot = try await db.collection("moderation_actions")
            .whereField("postId", isEqualTo: postId)
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        let actions = snapshot.documents.compactMap { doc -> ModerationAction? in
            try? doc.data(as: ModerationAction.self)
        }
        
        Logger.info("Found \(actions.count) moderation actions for post \(postId)", service: "ModerationService")
        return actions
    }
    
    func getPendingPosts(limit: Int = 50) async throws -> [Post] {
        Logger.info("Getting pending posts (limit: \(limit))", service: "ModerationService")
        
        let snapshot = try await db.collection("posts")
            .whereField("moderationStatus", isEqualTo: ModerationStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let posts = try await convertDocumentsToPosts(snapshot.documents)
        
        Logger.info("Found \(posts.count) pending posts", service: "ModerationService")
        return posts
    }
    
    func getFlaggedPosts(limit: Int = 50) async throws -> [Post] {
        Logger.info("Getting flagged posts (limit: \(limit))", service: "ModerationService")
        
        let snapshot = try await db.collection("posts")
            .whereField("moderationStatus", isEqualTo: ModerationStatus.flagged.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let posts = try await convertDocumentsToPosts(snapshot.documents)
        
        Logger.info("Found \(posts.count) flagged posts", service: "ModerationService")
        return posts
    }
    
    // MARK: - Helper Methods
    
    private func createModerationAction(
        postId: String,
        moderatorUserId: String,
        action: ModerationStatus,
        reason: String?,
        notes: String?,
        ruleName: String?
    ) async throws {
        let moderationAction = ModerationAction(
            postId: postId,
            moderatorUserId: moderatorUserId,
            action: action,
            reason: reason,
            notes: notes,
            ruleName: ruleName
        )
        
        let actionData = try Firestore.Encoder().encode(moderationAction)
        try await db.collection("moderation_actions").addDocument(data: actionData)
        
        Logger.debug("Created moderation action for post: \(postId)", service: "ModerationService")
    }
    
    private func convertDocumentsToPosts(_ documents: [QueryDocumentSnapshot]) async throws -> [Post] {
        // Collect unique user IDs
        var userIds = Set<String>()
        for doc in documents {
            if let userId = doc.data()["userId"] as? String {
                userIds.insert(userId)
            }
        }
        
        // Batch fetch profiles
        let profiles: [String: UserProfile]
        if !userIds.isEmpty {
            do {
                profiles = try await profileService.getUserProfiles(userIds: Array(userIds))
            } catch {
                Logger.warning("Failed to fetch user profiles: \(error.localizedDescription)", service: "ModerationService")
                profiles = [:]
            }
        } else {
            profiles = [:]
        }
        
        // Convert documents to posts
        var posts: [Post] = []
        for doc in documents {
            if let post = await Post.from(
                firestoreData: doc.data(),
                documentId: doc.documentID,
                profiles: profiles
            ) {
                posts.append(post)
            }
        }
        
        return posts
    }
}
