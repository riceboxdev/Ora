//
//  ProfileServiceProtocol.swift
//  OraBeta
//
//  Protocol for ProfileService to enable testability and dependency injection
//

import Foundation

/// Protocol defining the interface for profile management operations
@MainActor
protocol ProfileServiceProtocol {
    /// Get user profile by ID (with caching)
    func getUserProfile(userId: String) async throws -> UserProfile?
    
    /// Get multiple user profiles (batched for efficiency)
    func getUserProfiles(userIds: [String]) async throws -> [String: UserProfile]
    
    /// Clear profile cache (useful for testing or when profile is updated)
    func clearCache(userId: String?)
    
    /// Get current user profile
    func getCurrentUserProfile() async throws -> UserProfile?
    
    /// Create or update user profile
    func saveUserProfile(_ profile: UserProfile) async throws
    
    /// Update profile fields
    func updateProfile(userId: String, fields: [String: Any]) async throws
    
    /// Create profile from Firebase Auth user
    func createProfileFromAuthUser(email: String, displayName: String?) async throws
    
    /// Check if user is admin
    func isAdmin(userId: String) async throws -> Bool
    
    /// Check if profile exists for current user
    func profileExists() async throws -> Bool
    
    /// Manually create profile for current user (useful if profile creation failed during sign up)
    func createProfileForCurrentUser() async throws
    
    /// Follow a user
    func followUser(followingId: String) async throws
    
    /// Unfollow a user
    func unfollowUser(followingId: String) async throws
    
    /// Check if current user is following another user
    func isFollowing(followingId: String) async throws -> Bool
    
    /// Check if a username is available
    func checkUsernameAvailability(username: String) async throws -> Bool
    
    /// Complete onboarding with username and optional profile info
    func completeOnboarding(
        userId: String,
        username: String,
        displayName: String?,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws
}

