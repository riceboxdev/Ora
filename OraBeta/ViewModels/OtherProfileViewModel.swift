//
//  OtherProfileViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class OtherProfileViewModel: ObservableObject, PaginatableViewModel {
    // MARK: - Published Properties
    @Published var profile: UserProfile?
    @Published var posts: [Post] = []
    @Published var boards: [Board] = []
    @Published var isLoading = true
    @Published var isLoadingPosts = false
    @Published var isLoadingBoards = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var section: ProfileTabSection = .posts
    @Published var errorMessage: String?
    @Published var isFollowing = false
    @Published var isFollowingUser = false
    
    // MARK: - Private Properties
    private let profileService: ProfileServiceProtocol
    private var postService: PostServiceProtocol
    private var boardService: BoardService
    private let targetUserId: String
    private var currentUserId: String?
    private var lastPostDocument: QueryDocumentSnapshot?
    private let postsPerPage = 20
    private let container: DIContainer
    
    // MARK: - Initialization
    init(userId: String, container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        self.profileService = diContainer.profileService
        self.postService = diContainer.postService
        self.boardService = diContainer.boardService
        self.targetUserId = userId
    }
    
    // MARK: - Public Methods
    
    /// Load initial data (profile, posts, and boards)
    func loadInitialData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ OtherProfileViewModel: Cannot load data - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadProfile() }
            group.addTask { await self.loadUserPosts() }
            group.addTask { await self.loadBoards() }
            group.addTask { await self.checkFollowStatus() }
        }
    }
    
    /// Load user profile
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            profile = try await profileService.getUserProfile(userId: targetUserId)
            print("✅ OtherProfileViewModel: Loaded profile for user \(targetUserId)")
        } catch {
            print("❌ OtherProfileViewModel: Error loading profile: \(error)")
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load user's posts from Firestore (initial load)
    func loadUserPosts() async {
        isLoadingPosts = true
        lastPostDocument = nil // Reset pagination
        hasMore = true
        
        do {
            // Get posts for this user from Firestore
            let result = try await postService.getPosts(
                userId: targetUserId,
                limit: postsPerPage,
                lastDocument: nil
            )
            
            posts = result.posts
            lastPostDocument = result.lastDocument
            hasMore = result.posts.count >= postsPerPage
            
            print("✅ OtherProfileViewModel: Loaded \(posts.count) posts from Firestore")
        } catch {
            print("❌ OtherProfileViewModel: Error loading user posts: \(error)")
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
        }
        
        isLoadingPosts = false
    }
    
    /// Load more posts (pagination)
    func loadMorePosts() async {
        // Don't load if already loading or no more posts
        guard !isLoadingMore, hasMore, lastPostDocument != nil else {
            return
        }
        
        isLoadingMore = true
        
        do {
            let result = try await postService.getPosts(
                userId: targetUserId,
                limit: postsPerPage,
                lastDocument: lastPostDocument
            )
            
            // Append new posts
            posts.append(contentsOf: result.posts)
            lastPostDocument = result.lastDocument
            hasMore = result.posts.count >= postsPerPage
            
            print("✅ OtherProfileViewModel: Loaded \(result.posts.count) more posts. Total: \(posts.count)")
        } catch {
            print("❌ OtherProfileViewModel: Error loading more posts: \(error)")
        }
        
        isLoadingMore = false
    }
    
    /// Trigger load more from footer (explicit trigger)
    func loadMoreTriggered() {
        print("👇 Footer trigger activated (OtherProfileViewModel)")
        
        // Check if we can load more
        guard !isLoadingMore, hasMore, !isLoadingPosts else {
            print("❌ Cannot load more - isLoadingMore: \(isLoadingMore), hasMore: \(hasMore), isLoadingPosts: \(isLoadingPosts)")
            return
        }
        
        print("🚀 Triggering loadMorePosts() from footer")
        isLoadingMore = true
        
        Task {
            await loadMorePosts()
        }
    }
    
    /// Load user's boards
    func loadBoards() async {
        print("🔄 OtherProfileViewModel: Loading boards for user \(targetUserId)")
        
        isLoadingBoards = true
        errorMessage = nil
        
        do {
            let loadedBoards = try await boardService.getUserBoards(userId: targetUserId)
            boards = loadedBoards
            
            print("✅ OtherProfileViewModel: Loaded \(loadedBoards.count) boards")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ OtherProfileViewModel: Error loading boards: \(error)")
        }
        
        isLoadingBoards = false
    }
    
    /// Check follow status
    func checkFollowStatus() async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            isFollowing = try await profileService.isFollowing(followingId: targetUserId)
            print("✅ OtherProfileViewModel: Follow status checked - isFollowing: \(isFollowing)")
        } catch {
            print("❌ OtherProfileViewModel: Error checking follow status: \(error)")
            isFollowing = false
        }
    }
    
    /// Toggle follow status
    func toggleFollow() async {
        guard let currentUserId = currentUserId else { return }
        
        isFollowingUser = true
        
        do {
            if isFollowing {
                try await profileService.unfollowUser(followingId: targetUserId)
                isFollowing = false
                // Update follower count
                profile?.followerCount = max(0, (profile?.followerCount ?? 0) - 1)
                print("✅ OtherProfileViewModel: Unfollowed user \(targetUserId)")
            } else {
                try await profileService.followUser(followingId: targetUserId)
                isFollowing = true
                // Update follower count
                profile?.followerCount = (profile?.followerCount ?? 0) + 1
                print("✅ OtherProfileViewModel: Followed user \(targetUserId)")
            }
        } catch {
            print("❌ OtherProfileViewModel: Error toggling follow: \(error)")
            errorMessage = "Failed to toggle follow: \(error.localizedDescription)"
        }
        
        isFollowingUser = false
    }
    
    /// Refresh all data
    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadProfile() }
            group.addTask { await self.loadUserPosts() }
            group.addTask { await self.loadBoards() }
            group.addTask { await self.checkFollowStatus() }
        }
    }
    
    /// Load user posts (wrapper for refresh)
    func loadPosts() async {
        await loadUserPosts()
    }
}
