//
//  UserDiscoveryService.swift
//  OraBeta
//
//  Service to discover and recommend users for the discover feed
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UserDiscoveryService {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let postsCollection = "posts"
    private let followsCollection = "follows"
    private let profileService: ProfileService
    
    init(profileService: ProfileService? = nil) {
        self.profileService = profileService ?? ProfileService()
    }
    
    /// Get recommended users combining popular, similar interests, and recently active users
    /// - Parameter limit: Maximum number of users to return (default: 10)
    /// - Returns: Array of recommended UserProfile objects
    func getRecommendedUsers(limit: Int = 10) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserDiscoveryError.notAuthenticated
        }
        
        // Get current user profile to check preferences
        guard let currentUserProfile = try await profileService.getUserProfile(userId: currentUserId) else {
            throw UserDiscoveryError.userNotFound
        }
        
        // Fetch users from different sources in parallel
        async let popularUsers = fetchPopularUsers(limit: 5, excludeUserId: currentUserId)
        async let similarUsers = fetchSimilarUsers(currentUser: currentUserProfile, limit: 5, excludeUserId: currentUserId)
        async let recentUsers = fetchRecentlyActiveUsers(limit: 5, excludeUserId: currentUserId)
        
        // Wait for all results
        let (popular, similar, recent) = try await (popularUsers, similarUsers, recentUsers)
        
        // Combine and deduplicate
        var allUsers: [UserProfile] = []
        var seenUserIds: Set<String> = []
        
        // Add users in priority order: similar > popular > recent
        for user in similar {
            if let userId = user.id, !seenUserIds.contains(userId) {
                allUsers.append(user)
                seenUserIds.insert(userId)
            }
        }
        
        for user in popular {
            if let userId = user.id, !seenUserIds.contains(userId) {
                allUsers.append(user)
                seenUserIds.insert(userId)
            }
        }
        
        for user in recent {
            if let userId = user.id, !seenUserIds.contains(userId) {
                allUsers.append(user)
                seenUserIds.insert(userId)
            }
        }
        
        // Limit to requested amount
        return Array(allUsers.prefix(limit))
    }
    
    /// Fetch popular users (sorted by follower count)
    private func fetchPopularUsers(limit: Int, excludeUserId: String) async throws -> [UserProfile] {
        let query = db.collection(usersCollection)
            .whereField("followerCount", isGreaterThan: 0)
            .order(by: "followerCount", descending: true)
            .limit(to: limit * 2) // Fetch more to account for exclusions
        
        let snapshot = try await query.getDocuments()
        
        var users: [UserProfile] = []
        for document in snapshot.documents {
            // Skip current user
            if document.documentID == excludeUserId {
                continue
            }
            
            // Try to decode user profile
            if var profile = try? document.data(as: UserProfile.self) {
                profile.id = document.documentID
                users.append(profile)
                
                if users.count >= limit {
                    break
                }
            }
        }
        
        return users
    }
    
    /// Fetch users with similar interests based on preferences
    private func fetchSimilarUsers(currentUser: UserProfile, limit: Int, excludeUserId: String) async throws -> [UserProfile] {
        // Get user's preferred tags and categories
        let preferredTags = currentUser.preferredTags ?? []
        let preferredCategories = currentUser.preferredCategories ?? []
        
        // If user has no preferences, return empty
        guard !preferredTags.isEmpty || !preferredCategories.isEmpty else {
            return []
        }
        
        // Find users who have posts with matching tags or categories
        var candidateUserIds: Set<String> = []
        
        // Query posts with matching tags
        if !preferredTags.isEmpty {
            for tag in preferredTags.prefix(3) { // Limit to top 3 tags to avoid too many queries
                let tagQuery = db.collection(postsCollection)
                    .whereField("tags", arrayContains: tag)
                    .whereField("createdAt", isGreaterThan: Timestamp(date: Date().addingTimeInterval(-7 * 24 * 60 * 60))) // Last 7 days
                    .limit(to: 20)
                
                let snapshot = try? await tagQuery.getDocuments()
                snapshot?.documents.forEach { doc in
                    if let userId = doc.data()["userId"] as? String, userId != excludeUserId {
                        candidateUserIds.insert(userId)
                    }
                }
            }
        }
        
        // Query posts with matching categories
        if !preferredCategories.isEmpty {
            for category in preferredCategories.prefix(2) { // Limit to top 2 categories
                let categoryQuery = db.collection(postsCollection)
                    .whereField("categories", arrayContains: category)
                    .whereField("createdAt", isGreaterThan: Timestamp(date: Date().addingTimeInterval(-7 * 24 * 60 * 60))) // Last 7 days
                    .limit(to: 20)
                
                let snapshot = try? await categoryQuery.getDocuments()
                snapshot?.documents.forEach { doc in
                    if let userId = doc.data()["userId"] as? String, userId != excludeUserId {
                        candidateUserIds.insert(userId)
                    }
                }
            }
        }
        
        // Fetch profiles for candidate users
        guard !candidateUserIds.isEmpty else {
            return []
        }
        
        let userIds = Array(candidateUserIds.prefix(limit * 2))
        let profiles = try await profileService.getUserProfiles(userIds: userIds)
        
        // Sort by follower count and return top users
        return Array(profiles.values)
            .sorted { ($0.followerCount) > ($1.followerCount) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Fetch recently active users (users who posted in the last 7 days)
    private func fetchRecentlyActiveUsers(limit: Int, excludeUserId: String) async throws -> [UserProfile] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let timestamp = Timestamp(date: sevenDaysAgo)
        
        let query = db.collection(postsCollection)
            .whereField("createdAt", isGreaterThan: timestamp)
            .order(by: "createdAt", descending: true)
            .limit(to: limit * 3) // Fetch more to account for duplicates and exclusions
        
        let snapshot = try await query.getDocuments()
        
        // Extract unique user IDs
        var userIds: Set<String> = []
        for document in snapshot.documents {
            if let userId = document.data()["userId"] as? String, userId != excludeUserId {
                userIds.insert(userId)
                if userIds.count >= limit {
                    break
                }
            }
        }
        
        // Fetch profiles
        guard !userIds.isEmpty else {
            return []
        }
        
        let profiles = try await profileService.getUserProfiles(userIds: Array(userIds))
        return Array(profiles.values)
    }
    
    // MARK: - Related Users
    
    /// Get users who create similar content to a specific post
    /// - Parameters:
    ///   - post: The post to find related users for
    ///   - limit: Maximum number of users to return
    /// - Returns: Array of related UserProfile objects
    func getRelatedUsersForPost(_ post: Post, limit: Int = 10) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserDiscoveryError.notAuthenticated
        }
        
        // Get users the current user already follows
        let followedUserIds = try await getFollowedUserIds(for: currentUserId)
        
        // Get interests from the post
        let postInterests = post.interestIds ?? []
        
        // If no interests, return empty
        guard !postInterests.isEmpty else {
            return []
        }
        
        var candidateUserIds: Set<String> = []
        let thirtyDaysAgo = Timestamp(date: Date().addingTimeInterval(-30 * 24 * 60 * 60))
        
        // Find users who have posts with similar interests
        for interest in postInterests.prefix(5) {
            let interestQuery = db.collection(postsCollection)
                .whereField("interestIds", arrayContains: interest)
                .whereField("createdAt", isGreaterThan: thirtyDaysAgo)
                .limit(to: 30)
            
            if let snapshot = try? await interestQuery.getDocuments() {
                for doc in snapshot.documents {
                    if let userId = doc.data()["userId"] as? String,
                       userId != currentUserId,
                       userId != post.userId, // Exclude the post author
                       !followedUserIds.contains(userId) {
                        candidateUserIds.insert(userId)
                    }
                }
            }
        }
        
        guard !candidateUserIds.isEmpty else {
            return []
        }
        
        // Fetch profiles for candidates
        let profiles = try await profileService.getUserProfiles(userIds: Array(candidateUserIds.prefix(limit * 2)))
        
        // Sort by follower count and return top users
        return Array(profiles.values)
            .sorted { $0.followerCount > $1.followerCount }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Friends of Friends
    
    /// Get users followed by people the current user follows
    /// - Parameter limit: Maximum number of users to return
    /// - Returns: Array of suggested UserProfile objects
    func getFriendsOfFriends(limit: Int = 10) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserDiscoveryError.notAuthenticated
        }
        
        // Get users the current user follows
        let followedUserIds = try await getFollowedUserIds(for: currentUserId)
        
        // If user doesn't follow anyone, fall back to popular users
        guard !followedUserIds.isEmpty else {
            return try await fetchPopularUsers(limit: limit, excludeUserId: currentUserId)
        }
        
        // For each followed user, get who they follow
        var friendsOfFriendsIds: [String: Int] = [:] // userId -> count of mutual connections
        
        // Limit to checking first 20 followed users to avoid too many queries
        for followedUserId in followedUserIds.prefix(20) {
            // Get who this followed user follows
            let theirFollowsQuery = db.collection(followsCollection)
                .whereField("followerId", isEqualTo: followedUserId)
                .limit(to: 50)
            
            if let snapshot = try? await theirFollowsQuery.getDocuments() {
                for doc in snapshot.documents {
                    if let theirFollowingId = doc.data()["followingId"] as? String,
                       theirFollowingId != currentUserId,
                       !followedUserIds.contains(theirFollowingId) {
                        friendsOfFriendsIds[theirFollowingId, default: 0] += 1
                    }
                }
            }
        }
        
        // If no friends of friends found, fall back to popular users
        guard !friendsOfFriendsIds.isEmpty else {
            return try await fetchPopularUsers(limit: limit, excludeUserId: currentUserId)
        }
        
        // Sort by number of mutual connections (most connected first)
        let sortedUserIds = friendsOfFriendsIds
            .sorted { $0.value > $1.value }
            .map { $0.key }
            .prefix(limit * 2)
        
        // Fetch profiles
        let profiles = try await profileService.getUserProfiles(userIds: Array(sortedUserIds))
        
        // Return in order of mutual connections
        var orderedProfiles: [UserProfile] = []
        for userId in sortedUserIds {
            if let profile = profiles[userId] {
                orderedProfiles.append(profile)
                if orderedProfiles.count >= limit {
                    break
                }
            }
        }
        
        return orderedProfiles
    }
    
    // MARK: - Private Helpers
    
    /// Get IDs of users the specified user follows
    private func getFollowedUserIds(for userId: String) async throws -> Set<String> {
        let query = db.collection(followsCollection)
            .whereField("followerId", isEqualTo: userId)
        
        let snapshot = try await query.getDocuments()
        
        var followedIds: Set<String> = []
        for doc in snapshot.documents {
            if let followingId = doc.data()["followingId"] as? String {
                followedIds.insert(followingId)
            }
        }
        
        return followedIds
    }
}

enum UserDiscoveryError: LocalizedError {
    case notAuthenticated
    case userNotFound
    case fetchError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .userNotFound:
            return "Current user profile not found"
        case .fetchError(let message):
            return "Failed to fetch users: \(message)"
        }
    }
}

