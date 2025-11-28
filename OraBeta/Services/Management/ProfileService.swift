//
//  ProfileService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ProfileService: ProfileServiceProtocol {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    // In-memory cache for profiles
    private var profileCache: [String: UserProfile] = [:]
    private var loadingProfiles: Set<String> = []
    private var loadingTasks: [String: Task<UserProfile?, Error>] = [:]
    
    /// Get user profile by ID (with caching)
    func getUserProfile(userId: String) async throws -> UserProfile? {
        // Check cache first
        if let cachedProfile = profileCache[userId] {
            return cachedProfile
        }
        
        // Check if already loading this profile
        if let existingTask = loadingTasks[userId] {
            return try await existingTask.value
        }
        
        // Create loading task
        let task = Task<UserProfile?, Error> {
            let doc = try await db.collection(usersCollection).document(userId).getDocument()
            guard doc.exists else {
                Logger.warning("Profile document doesn't exist for user \(userId)", service: "ProfileService")
                return nil
            }
            var profile = try doc.data(as: UserProfile.self)
            // Explicitly set the ID from the document ID to ensure it's always populated
            profile.id = doc.documentID
            
            // Cache the profile
            await MainActor.run {
                profileCache[userId] = profile
                loadingTasks.removeValue(forKey: userId)
            }
            
            Logger.info("Loaded profile with ID: \(doc.documentID)", service: "ProfileService")
            return profile
        }
        
        loadingTasks[userId] = task
        return try await task.value
    }
    
    /// Get multiple user profiles (batched for efficiency)
    func getUserProfiles(userIds: [String]) async throws -> [String: UserProfile] {
        var profiles: [String: UserProfile] = [:]
        var missingUserIds: [String] = []
        
        // Check cache first
        for userId in userIds {
            if let cachedProfile = profileCache[userId] {
                profiles[userId] = cachedProfile
            } else {
                missingUserIds.append(userId)
            }
        }
        
        // If all profiles are cached, return immediately
        if missingUserIds.isEmpty {
            return profiles
        }
        
        // Fetch missing profiles in parallel
        await withTaskGroup(of: (String, UserProfile?).self) { group in
            for userId in missingUserIds {
                group.addTask {
                    if let profile = try? await self.getUserProfile(userId: userId) {
                        return (userId, profile)
                    }
                    return (userId, nil)
                }
            }
            
            for await (userId, profile) in group {
                if let profile = profile {
                    profiles[userId] = profile
                }
            }
        }
        
        return profiles
    }
    
    /// Clear profile cache (useful for testing or when profile is updated)
    func clearCache(userId: String? = nil) {
        if let userId = userId {
            profileCache.removeValue(forKey: userId)
        } else {
            profileCache.removeAll()
        }
    }
    
    /// Get current user profile
    func getCurrentUserProfile() async throws -> UserProfile? {
        guard let userId = Auth.auth().currentUser?.uid else {
            return nil
        }
        return try await getUserProfile(userId: userId)
    }
    
    /// Create or update user profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        guard let userId = profile.id ?? Auth.auth().currentUser?.uid else {
            throw ProfileError.noUserId
        }
        
        // Create a mutable copy without the id field (Firestore manages @DocumentID)
        var profileToSave = profile
        profileToSave.id = nil
        
        try db.collection(usersCollection).document(userId).setData(from: profileToSave, merge: true)
    }
    
    /// Update profile fields
    func updateProfile(
        userId: String,
        fields: [String: Any]
    ) async throws {
        guard userId == Auth.auth().currentUser?.uid else {
            throw ProfileError.unauthorized
        }
        
        try await db.collection(usersCollection).document(userId).updateData(fields)
    }
    
    /// Create profile from Firebase Auth user
    func createProfileFromAuthUser(email: String, displayName: String?    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.error("No user ID available", service: "ProfileService")
            throw ProfileError.noUserId
        }
        
        Logger.info("Creating profile for user \(userId)", service: "ProfileService")
        Logger.debug("   Email: \(email)", service: "ProfileService")
        Logger.debug("   Display name: \(displayName ?? "none")", service: "ProfileService")
        
        // Check if profile already exists
        if let existingProfile = try? await getUserProfile(userId: userId) {
            Logger.warning("Profile already exists for user \(userId)", service: "ProfileService")
            Logger.debug("   Existing username: \(existingProfile.username)", service: "ProfileService")
            // Don't overwrite existing profile, just return
            return
        }
        
        // Don't set id - it's managed by Firestore via @DocumentID
        let profile = UserProfile(
            id: nil,
            email: email,
            username: displayName ?? email.components(separatedBy: "@").first ?? "user",
            isAdmin: false
        )
        
        Logger.info("Saving profile to Firestore...", service: "ProfileService")
        do {
            try await saveUserProfile(profile)
            Logger.info("Profile saved successfully", service: "ProfileService")
        } catch {
            Logger.error("Failed to save profile: \(error.localizedDescription)", service: "ProfileService")
            if let nsError = error as NSError? {
                Logger.debug("   Error domain: \(nsError.domain)", service: "ProfileService")
                Logger.debug("   Error code: \(nsError.code)", service: "ProfileService")
                Logger.debug("   Error userInfo: \(nsError.userInfo)", service: "ProfileService")
            }
            throw error
        }
    }
    
    /// Check if user is admin
    func isAdmin(userId: String) async throws -> Bool {
        guard let profile = try await getUserProfile(userId: userId) else {
            return false
        }
        return profile.isAdmin
    }
    
    /// Check if profile exists for current user
    func profileExists() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        let doc = try await db.collection(usersCollection).document(userId).getDocument()
        return doc.exists
    }
    
    /// Manually create profile for current user (useful if profile creation failed during sign up)
    func createProfileForCurrentUser() async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw ProfileError.noUserId
        }
        
        let displayName = user.displayName
        try await createProfileFromAuthUser(email: email, displayName: displayName)
    }
    
    // MARK: - Follow/Unfollow
    
    /// Follow a user
    func followUser(followingId: String) async throws {
        guard let followerId = Auth.auth().currentUser?.uid else {
            throw ProfileError.noUserId
        }
        
        // Don't allow following yourself
        guard followerId != followingId else {
            throw ProfileError.cannotFollowSelf
        }
        
        // Check if already following
        let followId = "\(followerId)_\(followingId)"
        let followDoc = try await db.collection("follows").document(followId).getDocument()
        
        if followDoc.exists {
            Logger.info("Already following user \(followingId)", service: "ProfileService")
            return
        }
        
        // Create follow relationship in Firestore
        try await db.collection("follows").document(followId).setData([
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        // Update follower's following count (non-critical - can fail without breaking follow)
        do {
            try await db.collection(usersCollection).document(followerId).updateData([
                "followingCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.warning("Could not update follower's following count: \(error.localizedDescription)", service: "ProfileService")
        }
        
        // Update following user's follower count (non-critical - can fail without breaking follow)
        do {
            try await db.collection(usersCollection).document(followingId).updateData([
                "followerCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.warning("Could not update followed user's follower count: \(error.localizedDescription)", service: "ProfileService")
        }
        
        Logger.info("Successfully followed user \(followingId)", service: "ProfileService")
    }
    
    /// Unfollow a user
    func unfollowUser(followingId: String) async throws {
        guard let followerId = Auth.auth().currentUser?.uid else {
            throw ProfileError.noUserId
        }
        
        let followId = "\(followerId)_\(followingId)"
        let followDoc = try await db.collection("follows").document(followId).getDocument()
        
        guard followDoc.exists else {
            Logger.info("Not following user \(followingId)", service: "ProfileService")
            return
        }
        
        // Delete follow relationship from Firestore
        try await db.collection("follows").document(followId).delete()
        
        // Update follower's following count (non-critical - can fail without breaking unfollow)
        do {
            try await db.collection(usersCollection).document(followerId).updateData([
                "followingCount": FieldValue.increment(Int64(-1))
            ])
        } catch {
            Logger.warning("Could not update follower's following count: \(error.localizedDescription)", service: "ProfileService")
        }
        
        // Update following user's follower count (non-critical - can fail without breaking unfollow)
        do {
            try await db.collection(usersCollection).document(followingId).updateData([
                "followerCount": FieldValue.increment(Int64(-1))
            ])
        } catch {
            Logger.warning("Could not update followed user's follower count: \(error.localizedDescription)", service: "ProfileService")
        }
        
        Logger.info("Successfully unfollowed user \(followingId)", service: "ProfileService")
    }
    
    /// Check if current user is following another user
    func isFollowing(followingId: String) async throws -> Bool {
        guard let followerId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let followId = "\(followerId)_\(followingId)"
        let followDoc = try await db.collection("follows").document(followId).getDocument()
        return followDoc.exists
    }
    
    // MARK: - Username Availability
    
    /// Check if a username is available
    func checkUsernameAvailability(username: String) async throws -> Bool {
        let lowercasedUsername = username.lowercased()
        
        // Query for existing username (case-insensitive by using lowercased version)
        let snapshot = try await db.collection(usersCollection)
            .whereField("username", isEqualTo: lowercasedUsername)
            .limit(to: 1)
            .getDocuments()
        
        // Username is available if no documents found
        return snapshot.documents.isEmpty
    }
    
    // MARK: - Onboarding
    
    /// Complete onboarding with username and optional profile info
    func completeOnboarding(
        userId: String,
        username: String,
        displayName: String?,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws {
        guard userId == Auth.auth().currentUser?.uid else {
            throw ProfileError.unauthorized
        }
        
        var fields: [String: Any] = [
            "username": username.lowercased(),
            "isOnboardingCompleted": true
        ]
        
        if let displayName = displayName, !displayName.isEmpty {
            fields["displayName"] = displayName
        }
        
        if let bio = bio, !bio.isEmpty {
            fields["bio"] = bio
        }
        
        if let profilePhotoUrl = profilePhotoUrl, !profilePhotoUrl.isEmpty {
            fields["profilePhotoUrl"] = profilePhotoUrl
        }
        
        try await db.collection(usersCollection).document(userId).updateData(fields)
        
        // Clear cache so fresh data is fetched
        clearCache(userId: userId)
        
        Logger.info("Onboarding completed for user \(userId)", service: "ProfileService")
    }
}

enum ProfileError: LocalizedError {
    case noUserId
    case unauthorized
    case cannotFollowSelf
    
    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "No user ID available"
        case .unauthorized:
            return "Unauthorized to perform this action"
        case .cannotFollowSelf:
            return "Cannot follow yourself"
        }
    }
}

