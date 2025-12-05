//
//  UserSuggestionService.swift
//  OraBeta
//
//  Protocol and implementation for comprehensive user suggestions
//  Supports globally popular users, personalized suggestions, and related users
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Suggestion Types

/// Types of user suggestions available
enum UserSuggestionType {
    /// Users with the highest follower counts who are active
    case globallyPopular
    
    /// Personalized suggestions based on user's interests and engagement history
    case personalized
    
    /// Users who create similar content to a specific post
    case relatedToPost(Post)
    
    /// Users followed by people the current user follows
    case friendsOfFriends
}

// MARK: - Protocol

/// Protocol defining user suggestion capabilities
protocol UserSuggestionServiceProtocol {
    /// Get globally popular users (highest follower counts)
    /// - Parameter limit: Maximum number of users to return
    /// - Returns: Array of popular UserProfile objects
    func getGloballyPopularUsers(limit: Int) async throws -> [UserProfile]
    
    /// Get personalized user suggestions based on user's interests
    /// - Parameter limit: Maximum number of users to return
    /// - Returns: Array of suggested UserProfile objects
    func getPersonalizedSuggestions(limit: Int) async throws -> [UserProfile]
    
    /// Get users who create similar content to a specific post
    /// - Parameters:
    ///   - post: The post to find related users for
    ///   - limit: Maximum number of users to return
    /// - Returns: Array of related UserProfile objects
    func getRelatedUsers(for post: Post, limit: Int) async throws -> [UserProfile]
    
    /// Get users followed by people the current user follows
    /// - Parameter limit: Maximum number of users to return
    /// - Returns: Array of suggested UserProfile objects
    func getFriendsOfFriends(limit: Int) async throws -> [UserProfile]
    
    /// Get user suggestions based on type
    /// - Parameters:
    ///   - type: The type of suggestion to fetch
    ///   - limit: Maximum number of users to return
    /// - Returns: Array of UserProfile objects
    func getSuggestions(type: UserSuggestionType, limit: Int) async throws -> [UserProfile]
}

// MARK: - Implementation

/// Service providing comprehensive user suggestions
@MainActor
class UserSuggestionService: UserSuggestionServiceProtocol {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let postsCollection = "posts"
    private let followsCollection = "follows"
    private let profileService: ProfileService
    
    init(profileService: ProfileService? = nil) {
        self.profileService = profileService ?? ProfileService()
    }
    
    // MARK: - Public Methods
    
    /// Get user suggestions based on type
    func getSuggestions(type: UserSuggestionType, limit: Int) async throws -> [UserProfile] {
        switch type {
        case .globallyPopular:
            return try await getGloballyPopularUsers(limit: limit)
        case .personalized:
            return try await getPersonalizedSuggestions(limit: limit)
        case .relatedToPost(let post):
            return try await getRelatedUsers(for: post, limit: limit)
        case .friendsOfFriends:
            return try await getFriendsOfFriends(limit: limit)
        }
    }
    
    /// Get globally popular users sorted by follower count
    func getGloballyPopularUsers(limit: Int) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserSuggestionError.notAuthenticated
        }
        
        // Get users the current user already follows
        let followedUserIds = try await getFollowedUserIds(for: currentUserId)
        
        let query = db.collection(usersCollection)
            .whereField("followerCount", isGreaterThan: 0)
            .order(by: "followerCount", descending: true)
            .limit(to: limit * 3) // Fetch more to account for filtering
        
        let snapshot = try await query.getDocuments()
        
        var users: [UserProfile] = []
        for document in snapshot.documents {
            let userId = document.documentID
            
            // Skip current user and users already followed
            if userId == currentUserId || followedUserIds.contains(userId) {
                continue
            }
            
            if var profile = try? document.data(as: UserProfile.self) {
                profile.id = userId
                users.append(profile)
                
                if users.count >= limit {
                    break
                }
            }
        }
        
        return users
    }
    
    /// Get personalized user suggestions based on user's interests
    func getPersonalizedSuggestions(limit: Int) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserSuggestionError.notAuthenticated
        }
        
        // Get current user profile
        guard let currentUser = try await profileService.getUserProfile(userId: currentUserId) else {
            throw UserSuggestionError.userNotFound
        }
        
        // Get users already followed
        let followedUserIds = try await getFollowedUserIds(for: currentUserId)
        
        // Get preferred tags and categories
        let preferredTags = currentUser.preferredTags ?? []
        let preferredCategories = currentUser.preferredCategories ?? []
        
        // If no preferences, fall back to popular users
        guard !preferredTags.isEmpty || !preferredCategories.isEmpty else {
            return try await getGloballyPopularUsers(limit: limit)
        }
        
        // Find users who post content matching user's preferences
        var candidateUserIds: Set<String> = []
        let sevenDaysAgo = Timestamp(date: Date().addingTimeInterval(-7 * 24 * 60 * 60))
        
        // Query posts with matching tags
        for tag in preferredTags.prefix(3) {
            let tagQuery = db.collection(postsCollection)
                .whereField("tags", arrayContains: tag)
                .whereField("createdAt", isGreaterThan: sevenDaysAgo)
                .limit(to: 20)
            
            if let snapshot = try? await tagQuery.getDocuments() {
                for doc in snapshot.documents {
                    if let userId = doc.data()["userId"] as? String,
                       userId != currentUserId,
                       !followedUserIds.contains(userId) {
                        candidateUserIds.insert(userId)
                    }
                }
            }
        }
        
        // Query posts with matching categories
        for category in preferredCategories.prefix(2) {
            let categoryQuery = db.collection(postsCollection)
                .whereField("categories", arrayContains: category)
                .whereField("createdAt", isGreaterThan: sevenDaysAgo)
                .limit(to: 20)
            
            if let snapshot = try? await categoryQuery.getDocuments() {
                for doc in snapshot.documents {
                    if let userId = doc.data()["userId"] as? String,
                       userId != currentUserId,
                       !followedUserIds.contains(userId) {
                        candidateUserIds.insert(userId)
                    }
                }
            }
        }
        
        // If no candidates found, fall back to popular users
        guard !candidateUserIds.isEmpty else {
            return try await getGloballyPopularUsers(limit: limit)
        }
        
        // Fetch profiles for candidates
        let profiles = try await profileService.getUserProfiles(userIds: Array(candidateUserIds.prefix(limit * 2)))
        
        // Sort by follower count and return top users
        return Array(profiles.values)
            .sorted { $0.followerCount > $1.followerCount }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get users who create similar content to a specific post
    func getRelatedUsers(for post: Post, limit: Int) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserSuggestionError.notAuthenticated
        }
        
        // Get users already followed
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
    
    /// Get users followed by people the current user follows (friends of friends)
    func getFriendsOfFriends(limit: Int) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw UserSuggestionError.notAuthenticated
        }
        
        // Get users the current user follows
        let followedUserIds = try await getFollowedUserIds(for: currentUserId)
        
        // If user doesn't follow anyone, fall back to popular users
        guard !followedUserIds.isEmpty else {
            return try await getGloballyPopularUsers(limit: limit)
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
            return try await getGloballyPopularUsers(limit: limit)
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

// MARK: - Errors

enum UserSuggestionError: LocalizedError {
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




