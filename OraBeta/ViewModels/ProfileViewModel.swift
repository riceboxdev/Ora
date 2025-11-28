//
//  ProfileViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class ProfileViewModel: ObservableObject, PaginatableViewModel {
    // MARK: - Published Properties
    @Published var profile: UserProfile?
    @Published var posts: [Post] = []
    @Published var boards: [Board] = []
    @Published var isLoading = true
    @Published var isLoadingPosts = false
    @Published var isLoadingBoards = false
    @Published var isLoadingMore = false // Renamed from isLoadingMorePosts for protocol conformance
    @Published var hasMore = true // Renamed from hasMorePosts for protocol conformance
    @Published var section: ProfileTabSection = .posts
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let profileService: ProfileServiceProtocol
    private var postService: PostServiceProtocol
    private var boardService: BoardService
    private var currentUserId: String?
    private var lastPostDocument: QueryDocumentSnapshot?
    private let postsPerPage = 20
    private let container: DIContainer
    
    // MARK: - Initialization
    init(container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        self.profileService = diContainer.profileService
        self.postService = diContainer.postService
        self.boardService = diContainer.boardService
    }
    
    // MARK: - Public Methods
    
    /// Load initial data (profile, posts, and boards)
    func loadInitialData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ ProfileViewModel: Cannot load data - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        await loadProfile()
        await loadUserPosts()
        await loadBoards()
    }
    
    /// Load user profile
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            var loadedProfile = try await profileService.getCurrentUserProfile()
            
            // If profile doesn't exist, try to create it
            if loadedProfile == nil {
                print("⚠️ ProfileViewModel: Profile doesn't exist, attempting to create it...")
                do {
                    try await profileService.createProfileForCurrentUser()
                    // Try loading again after creation
                    loadedProfile = try await profileService.getCurrentUserProfile()
                    if loadedProfile != nil {
                        print("✅ ProfileViewModel: Profile created and loaded successfully")
                    }
                } catch {
                    print("❌ ProfileViewModel: Failed to create profile: \(error.localizedDescription)")
                    errorMessage = "Failed to create profile: \(error.localizedDescription)"
                }
            }
            
            profile = loadedProfile
        } catch {
            print("❌ ProfileViewModel: Error loading profile: \(error)")
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error userInfo: \(nsError.userInfo)")
            }
        }
        
        isLoading = false
    }
    
    /// Load user's posts from Firestore (initial load)
    func loadUserPosts() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ ProfileViewModel: Cannot load posts - no user ID")
            return
        }
        
        isLoadingPosts = true
        lastPostDocument = nil // Reset pagination
        hasMore = true
        
        do {
            // Get posts for this user from Firestore
            let result = try await postService.getPosts(
                userId: userId,
                limit: postsPerPage,
                lastDocument: nil
            )
            
            posts = result.posts
            lastPostDocument = result.lastDocument
            hasMore = result.posts.count >= postsPerPage
            
            print("✅ ProfileViewModel: Loaded \(posts.count) posts from Firestore")
        } catch {
            print("❌ ProfileViewModel: Error loading user posts: \(error)")
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
        
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ ProfileViewModel: Cannot load more posts - no user ID")
            return
        }
        
        isLoadingMore = true
        
        do {
            let result = try await postService.getPosts(
                userId: userId,
                limit: postsPerPage,
                lastDocument: lastPostDocument
            )
            
            // Append new posts
            posts.append(contentsOf: result.posts)
            lastPostDocument = result.lastDocument
            hasMore = result.posts.count >= postsPerPage
            
            print("✅ ProfileViewModel: Loaded \(result.posts.count) more posts. Total: \(posts.count)")
        } catch {
            print("❌ ProfileViewModel: Error loading more posts: \(error)")
        }
        
        isLoadingMore = false
    }
    
    /// Trigger load more from footer (explicit trigger)
    func loadMoreTriggered() {
        print("👇 Footer trigger activated (ProfileViewModel)")
        
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
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ ProfileViewModel: Cannot load boards - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        print("🔄 ProfileViewModel: Loading boards for user \(userId)")
        
        isLoadingBoards = true
        errorMessage = nil
        
        do {
            let loadedBoards = try await boardService.getUserBoards(userId: userId)
            boards = loadedBoards
            
            print("✅ ProfileViewModel: Loaded \(loadedBoards.count) boards")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ ProfileViewModel: Error loading boards: \(error)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error description: \(nsError.localizedDescription)")
            }
        }
        
        isLoadingBoards = false
    }
    
    /// Refresh all data
    func refresh() async {
        await loadProfile()
        await loadUserPosts()
        await loadBoards()
    }
    
    /// Delete a post by ID
    @MainActor
    func deletePost(postId: String) async throws {
        print("🗑️ ProfileViewModel: Deleting post \(postId)")
        
        // Remove from local array immediately for UI responsiveness
        posts.removeAll { $0.id == postId }
        
        // Delete from backend
        try await postService.deletePost(postId: postId)
        
        print("✅ ProfileViewModel: Post deleted successfully")
    }
    
    /// Load user posts (wrapper for refresh)
    @MainActor
    func loadPosts() async {
        await loadUserPosts()
    }
}

