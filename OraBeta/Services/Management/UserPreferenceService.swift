//
//  UserPreferenceService.swift
//  OraBeta
//
//  Service to manage user preferences and build interest profiles from engagement
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UserPreferenceService {
    private let db = Firestore.firestore()
    private let profileService: ProfileService
    private let usersCollection = "users"
    private let postsCollection = "posts"
    
    // Engagement weights for preference calculation
    private let likeWeight: Double = 3.0
    private let commentWeight: Double = 5.0
    private let saveWeight: Double = 4.0
    private let shareWeight: Double = 2.0
    private let viewWeight: Double = 0.1 // Views are less important
    private let viewDurationThreshold: TimeInterval = 3.0 // Only count views > 3 seconds
    
    // Preference calculation settings
    private let minEngagementCount = 5 // Minimum engagements before building preferences
    private let topLabelsCount = 20 // Top N labels to store
    private let topTagsCount = 15 // Top N tags to store
    private let topCategoriesCount = 10 // Top N categories to store
    private let decayFactor = 0.95 // Decay factor for older engagements (not implemented yet)
    
    init(profileService: ProfileService? = nil) {
        self.profileService = profileService ?? ProfileService()
    }
    
    /// Update user preferences from a post engagement
    /// - Parameters:
    ///   - postId: The post ID that was engaged with
    ///   - engagementType: Type of engagement (like, comment, save, share, view)
    ///   - duration: Duration of view (for view engagements)
    func updatePreferencesFromEngagement(
        postId: String,
        engagementType: EngagementType,
        duration: TimeInterval? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot update preferences - no user ID", service: "UserPreferenceService")
            return
        }
        
        // Skip low-quality views
        if engagementType == .view, let duration = duration, duration < viewDurationThreshold {
            return
        }
        
        // Get post data
        let postDoc = try await db.collection(postsCollection).document(postId).getDocument()
        guard postDoc.exists, let postData = postDoc.data() else {
            Logger.warning("Post \(postId) not found", service: "UserPreferenceService")
            return
        }
        
        // Extract post metadata
        let semanticLabels = postData["semanticLabels"] as? [String] ?? []
        let tags = postData["tags"] as? [String] ?? []
        let categories = postData["categories"] as? [String] ?? []
        
        // Get engagement weight
        let weight = getEngagementWeight(engagementType)
        
        // Update preferences in background (non-blocking)
        Task {
            do {
                try await updatePreferences(
                    userId: userId,
                    labels: semanticLabels,
                    tags: tags,
                    categories: categories,
                    weight: weight
                )
            } catch {
                Logger.warning("Failed to update preferences: \(error.localizedDescription)", service: "UserPreferenceService")
            }
        }
    }
    
    /// Update user preferences with new engagement data
    private func updatePreferences(
        userId: String,
        labels: [String],
        tags: [String],
        categories: [String],
        weight: Double
    ) async throws {
        // Get current user profile
        guard var profile = try await profileService.getUserProfile(userId: userId) else {
            Logger.warning("User profile not found for \(userId)", service: "UserPreferenceService")
            return
        }
        
        // Initialize preference dictionaries if needed
        var labelWeights = profile.labelWeights ?? [:]
        var tagWeights = profile.tagWeights ?? [:]
        var categoryWeights = profile.categoryWeights ?? [:]
        
        // Update label weights
        for label in labels {
            let normalizedLabel = label.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalizedLabel.isEmpty {
                labelWeights[normalizedLabel] = (labelWeights[normalizedLabel] ?? 0.0) + weight
            }
        }
        
        // Update tag weights
        for tag in tags {
            let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalizedTag.isEmpty {
                tagWeights[normalizedTag] = (tagWeights[normalizedTag] ?? 0.0) + weight
            }
        }
        
        // Update category weights
        for category in categories {
            let normalizedCategory = category.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalizedCategory.isEmpty {
                categoryWeights[normalizedCategory] = (categoryWeights[normalizedCategory] ?? 0.0) + weight
            }
        }
        
        // Update total engagements
        profile.totalEngagements += 1
        
        // Calculate top preferences (only if we have enough engagements)
        if profile.totalEngagements >= minEngagementCount {
            // Get top labels
            let sortedLabels = labelWeights.sorted { $0.value > $1.value }
            let topLabels = Array(sortedLabels.prefix(topLabelsCount)).map { $0.key }
            
            // Get top tags
            let sortedTags = tagWeights.sorted { $0.value > $1.value }
            let topTags = Array(sortedTags.prefix(topTagsCount)).map { $0.key }
            
            // Get top categories
            let sortedCategories = categoryWeights.sorted { $0.value > $1.value }
            let topCategories = Array(sortedCategories.prefix(topCategoriesCount)).map { $0.key }
            
            // Update profile
            profile.preferredLabels = topLabels.isEmpty ? nil : topLabels
            profile.preferredTags = topTags.isEmpty ? nil : topTags
            profile.preferredCategories = topCategories.isEmpty ? nil : topCategories
        }
        
        // Update weights and metadata
        profile.labelWeights = labelWeights.isEmpty ? nil : labelWeights
        profile.tagWeights = tagWeights.isEmpty ? nil : tagWeights
        profile.categoryWeights = categoryWeights.isEmpty ? nil : categoryWeights
        profile.lastPreferencesUpdate = Date()
        
        // Save updated profile
        try await profileService.saveUserProfile(profile)
        
        Logger.info("Updated preferences for user \(userId)", service: "UserPreferenceService")
        Logger.debug("Total engagements: \(profile.totalEngagements)", service: "UserPreferenceService")
        Logger.debug("Preferred labels: \(profile.preferredLabels?.count ?? 0)", service: "UserPreferenceService")
        Logger.debug("Preferred tags: \(profile.preferredTags?.count ?? 0)", service: "UserPreferenceService")
        Logger.debug("Preferred categories: \(profile.preferredCategories?.count ?? 0)", service: "UserPreferenceService")
    }
    
    /// Get engagement weight for a given engagement type
    private func getEngagementWeight(_ engagementType: EngagementType) -> Double {
        switch engagementType {
        case .like:
            return likeWeight
        case .comment:
            return commentWeight
        case .save:
            return saveWeight
        case .share:
            return shareWeight
        case .view:
            return viewWeight
        }
    }
    
    /// Rebuild user preferences from all engagements (useful for migration or recalculation)
    func rebuildPreferences(userId: String) async throws {
        Logger.info("Rebuilding preferences for user \(userId)", service: "UserPreferenceService")
        
        // Get all user engagements
        let likes = try await getLikes(userId: userId)
        let comments = try await getComments(userId: userId)
        let saves = try await getSaves(userId: userId)
        let shares = try await getShares(userId: userId)
        let views = try await getViews(userId: userId)
        
        // Process all engagements
        var labelWeights: [String: Double] = [:]
        var tagWeights: [String: Double] = [:]
        var categoryWeights: [String: Double] = [:]
        var totalEngagements = 0
        
        // Process likes
        for like in likes {
            if let postData = try await getPostData(postId: like.postId) {
                processPostData(
                    postData: postData,
                    weight: likeWeight,
                    labelWeights: &labelWeights,
                    tagWeights: &tagWeights,
                    categoryWeights: &categoryWeights
                )
                totalEngagements += 1
            }
        }
        
        // Process comments
        for comment in comments {
            if let postData = try await getPostData(postId: comment.postId) {
                processPostData(
                    postData: postData,
                    weight: commentWeight,
                    labelWeights: &labelWeights,
                    tagWeights: &tagWeights,
                    categoryWeights: &categoryWeights
                )
                totalEngagements += 1
            }
        }
        
        // Process saves
        for save in saves {
            if let postData = try await getPostData(postId: save.postId) {
                processPostData(
                    postData: postData,
                    weight: saveWeight,
                    labelWeights: &labelWeights,
                    tagWeights: &tagWeights,
                    categoryWeights: &categoryWeights
                )
                totalEngagements += 1
            }
        }
        
        // Process shares
        for share in shares {
            if let postData = try await getPostData(postId: share.postId) {
                processPostData(
                    postData: postData,
                    weight: shareWeight,
                    labelWeights: &labelWeights,
                    tagWeights: &tagWeights,
                    categoryWeights: &categoryWeights
                )
                totalEngagements += 1
            }
        }
        
        // Process views (only significant views)
        for view in views where view.duration ?? 0 >= viewDurationThreshold {
            if let postData = try await getPostData(postId: view.postId) {
                processPostData(
                    postData: postData,
                    weight: viewWeight,
                    labelWeights: &labelWeights,
                    tagWeights: &tagWeights,
                    categoryWeights: &categoryWeights
                )
                totalEngagements += 1
            }
        }
        
        // Update profile with rebuilt preferences
        guard var profile = try await profileService.getUserProfile(userId: userId) else {
            throw UserPreferenceError.profileNotFound
        }
        
        // Calculate top preferences
        let sortedLabels = labelWeights.sorted { $0.value > $1.value }
        let topLabels = Array(sortedLabels.prefix(topLabelsCount)).map { $0.key }
        
        let sortedTags = tagWeights.sorted { $0.value > $1.value }
        let topTags = Array(sortedTags.prefix(topTagsCount)).map { $0.key }
        
        let sortedCategories = categoryWeights.sorted { $0.value > $1.value }
        let topCategories = Array(sortedCategories.prefix(topCategoriesCount)).map { $0.key }
        
        // Update profile
        profile.preferredLabels = topLabels.isEmpty ? nil : topLabels
        profile.preferredTags = topTags.isEmpty ? nil : topTags
        profile.preferredCategories = topCategories.isEmpty ? nil : topCategories
        profile.labelWeights = labelWeights.isEmpty ? nil : labelWeights
        profile.tagWeights = tagWeights.isEmpty ? nil : tagWeights
        profile.categoryWeights = categoryWeights.isEmpty ? nil : categoryWeights
        profile.totalEngagements = totalEngagements
        profile.lastPreferencesUpdate = Date()
        
        // Save profile
        try await profileService.saveUserProfile(profile)
        
        Logger.info("Rebuilt preferences for user \(userId)", service: "UserPreferenceService")
        Logger.debug("Total engagements: \(totalEngagements)", service: "UserPreferenceService")
        Logger.debug("Preferred labels: \(topLabels.count)", service: "UserPreferenceService")
        Logger.debug("Preferred tags: \(topTags.count)", service: "UserPreferenceService")
        Logger.debug("Preferred categories: \(topCategories.count)", service: "UserPreferenceService")
    }
    
    /// Process post data and update weight dictionaries
    private func processPostData(
        postData: [String: Any],
        weight: Double,
        labelWeights: inout [String: Double],
        tagWeights: inout [String: Double],
        categoryWeights: inout [String: Double]
    ) {
        let labels = postData["semanticLabels"] as? [String] ?? []
        let tags = postData["tags"] as? [String] ?? []
        let categories = postData["categories"] as? [String] ?? []
        
        for label in labels {
            let normalized = label.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalized.isEmpty {
                labelWeights[normalized] = (labelWeights[normalized] ?? 0.0) + weight
            }
        }
        
        for tag in tags {
            let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalized.isEmpty {
                tagWeights[normalized] = (tagWeights[normalized] ?? 0.0) + weight
            }
        }
        
        for category in categories {
            let normalized = category.lowercased().trimmingCharacters(in: .whitespaces)
            if !normalized.isEmpty {
                categoryWeights[normalized] = (categoryWeights[normalized] ?? 0.0) + weight
            }
        }
    }
    
    /// Get post data from Firestore
    private func getPostData(postId: String) async throws -> [String: Any]? {
        let doc = try await db.collection(postsCollection).document(postId).getDocument()
        return doc.data()
    }
    
    // MARK: - Engagement Data Retrieval
    
    /// Get all likes for a user
    private func getLikes(userId: String) async throws -> [LikeEngagement] {
        let snapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let postId = data["postId"] as? String else { return nil }
            return LikeEngagement(postId: postId, createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
        }
    }
    
    /// Get all comments for a user
    private func getComments(userId: String) async throws -> [CommentEngagement] {
        let snapshot = try await db.collection("comments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let postId = data["postId"] as? String else { return nil }
            return CommentEngagement(postId: postId, createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
        }
    }
    
    /// Get all saves for a user
    private func getSaves(userId: String) async throws -> [SaveEngagement] {
        let snapshot = try await db.collection("board_posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let postId = data["postId"] as? String else { return nil }
            return SaveEngagement(postId: postId, createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
        }
    }
    
    /// Get all shares for a user
    private func getShares(userId: String) async throws -> [ShareEngagement] {
        let snapshot = try await db.collection("post_interactions")
            .whereField("userId", isEqualTo: userId)
            .whereField("interactionType", isEqualTo: "share")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let postId = data["postId"] as? String else { return nil }
            return ShareEngagement(postId: postId, createdAt: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date())
        }
    }
    
    /// Get all views for a user (with duration)
    private func getViews(userId: String) async throws -> [ViewEngagement] {
        let snapshot = try await db.collection("post_interactions")
            .whereField("userId", isEqualTo: userId)
            .whereField("interactionType", isEqualTo: "view")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let postId = data["postId"] as? String else { return nil }
            let duration = data["duration"] as? TimeInterval
            return ViewEngagement(postId: postId, duration: duration, createdAt: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date())
        }
    }
}

// MARK: - Supporting Types

enum EngagementType {
    case like
    case comment
    case save
    case share
    case view
}

struct LikeEngagement {
    let postId: String
    let createdAt: Date
}

struct CommentEngagement {
    let postId: String
    let createdAt: Date
}

struct SaveEngagement {
    let postId: String
    let createdAt: Date
}

struct ShareEngagement {
    let postId: String
    let createdAt: Date
}

struct ViewEngagement {
    let postId: String
    let duration: TimeInterval?
    let createdAt: Date
}

enum UserPreferenceError: LocalizedError {
    case profileNotFound
    case invalidEngagement
    case rebuildFailed
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile not found"
        case .invalidEngagement:
            return "Invalid engagement data"
        case .rebuildFailed:
            return "Failed to rebuild preferences"
        }
    }
}












