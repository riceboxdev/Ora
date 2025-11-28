//
//  PostDetailViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class PostDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var likeCount: Int = 0
    @Published var commentCount: Int = 0
    @Published var showBoards: Bool = false
    @Published var boards: [Board] = []
    @Published var isLoadingBoards: Bool = false
    @Published var isSavingToBoard: Bool = false
    @Published var isLiked: Bool = false
    @Published var likeReactionId: String?
    @Published var isFollowing: Bool = false
    @Published var isLoading: Bool = false
    @Published var isLiking: Bool = false
    @Published var isFollowingUser: Bool = false
    @Published var errorMessage: String?
    @Published var latestComment: Comment?
    @Published var latestCommentProfile: UserProfile?
    @Published var recommendedPosts: [Post] = []
    @Published var isLoadingRecommendations: Bool = false
    @Published var relatedUsers: [UserProfile] = []
    @Published var isLoadingRelatedUsers: Bool = false
    @Published var boardsContainingPost: Set<String> = [] // Set of board IDs that contain this post
    
    // MARK: - Private Properties
    let post: Post
    private var engagementService: EngagementService
    private var boardService: BoardService
    private let profileService: ProfileServiceProtocol
    private let userDiscoveryService: UserDiscoveryService
    private var currentUserId: String?
    private let feedGroup: String
    private let feedId: String
    
    // MARK: - Private Properties
    private let container: DIContainer
    
    // MARK: - Initialization
    init(post: Post, feedGroup: String = "user", feedId: String? = nil, container: DIContainer? = nil) {
        self.post = post
        self.feedGroup = feedGroup
        self.feedId = feedId ?? post.userId
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        
        // Initialize services from container
        self.boardService = diContainer.boardService
        self.engagementService = diContainer.engagementService
        self.profileService = diContainer.profileService
        self.userDiscoveryService = diContainer.userDiscoveryService
        
        // Initialize counts from post (fallback values)
        self.likeCount = post.likeCount
        self.commentCount = post.commentCount
    }
    
    // MARK: - Public Methods
    
    /// Load all initial state (counts, like status, follow status)
    func loadInitialState() async {
        isLoading = true
        errorMessage = nil
        
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        // Load all data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLikeCount() }
            group.addTask { await self.loadCommentCount() }
            group.addTask { await self.loadLikeStatus() }
            group.addTask { await self.loadFollowStatus() }
            group.addTask { await self.loadLatestComment() }
            group.addTask { await self.loadRecommendedPosts() }
            group.addTask { await self.loadRelatedUsers() }
        }
        
        isLoading = false
    }
    
    
    /// Load like count from Firestore
    func loadLikeCount() async {
        do {
            let count = try await engagementService.getLikeCount(postId: post.id)
            likeCount = count
            print("✅ PostDetailViewModel: Loaded like count: \(count)")
        } catch {
            print("⚠️ PostDetailViewModel: Error loading like count: \(error.localizedDescription)")
            errorMessage = "Failed to load like count"
        }
    }
    
    /// Load comment count from Firestore
    func loadCommentCount() async {
        do {
            let count = try await engagementService.getCommentCount(postId: post.id)
            commentCount = count
            print("✅ PostDetailViewModel: Loaded comment count: \(count)")
        } catch {
            print("⚠️ PostDetailViewModel: Error loading comment count: \(error.localizedDescription)")
            errorMessage = "Failed to load comment count"
        }
    }
    
    /// Load like status for current user
    func loadLikeStatus() async {
        guard currentUserId != nil else { return }
        
        do {
            let (liked, likeId) = try await engagementService.hasLiked(postId: post.id)
            isLiked = liked
            likeReactionId = likeId
            print("✅ PostDetailViewModel: Loaded like status: \(liked)")
        } catch {
            print("⚠️ PostDetailViewModel: Error loading like status: \(error.localizedDescription)")
        }
    }
    
    /// Load follow status for post author
    func loadFollowStatus() async {
        guard let userId = currentUserId, userId != post.userId else {
            return
        }
        
        do {
            isFollowing = try await profileService.isFollowing(followingId: post.userId)
            print("✅ PostDetailViewModel: Loaded follow status: \(isFollowing)")
        } catch {
            print("⚠️ PostDetailViewModel: Error loading follow status: \(error.localizedDescription)")
        }
    }
    
    /// Toggle like on the post (optimistic UI update)
    func toggleLike() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to like posts"
            return
        }
        
        currentUserId = userId
        
        // Prevent multiple simultaneous like operations
        guard !isLiking else { return }
        
        isLiking = true
        errorMessage = nil
        
        // Store previous state for rollback
        let previousLikedState = isLiked
        let previousReactionId = likeReactionId
        let previousLikeCount = likeCount
        
        // Optimistic UI update - update immediately
        if isLiked {
            // Optimistically unlike
            isLiked = false
            likeReactionId = nil
            likeCount = max(0, likeCount - 1)
        } else {
            // Optimistically like
            isLiked = true
            likeCount += 1
        }
        
        do {
            if previousLikedState {
                // Unlike
                try await engagementService.unlikePost(postId: post.id)
                
                // Refresh like count to get accurate value
                await loadLikeCount()
            } else {
                // Like
                let likeId = try await engagementService.likePost(postId: post.id)
                likeReactionId = likeId
                
                // Track like event with Algolia Insights
                await AlgoliaInsightsService.shared.trackLike(objectID: post.id)
                
                // Refresh like count to get accurate value
                await loadLikeCount()
            }
        } catch {
            print("❌ PostDetailViewModel: Error toggling like: \(error.localizedDescription)")
            
            // Rollback optimistic update on error
            isLiked = previousLikedState
            likeReactionId = previousReactionId
            likeCount = previousLikeCount
            
            errorMessage = "Failed to update like: \(error.localizedDescription)"
        }
        
        isLiking = false
    }
    
    /// Toggle follow status for post author
    func toggleFollow() async {
        guard let userId = currentUserId, userId != post.userId else {
            return
        }
        
        isFollowingUser = true
        errorMessage = nil
        
        do {
            if isFollowing {
                try await profileService.unfollowUser(followingId: post.userId)
                isFollowing = false
            } else {
                try await profileService.followUser(followingId: post.userId)
                isFollowing = true
            }
            
            // Post notification to refresh home feed after follow/unfollow
            NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
            print("✅ PostDetailViewModel: Posted feed refresh notification after follow/unfollow")
        } catch {
            print("❌ PostDetailViewModel: Error toggling follow: \(error.localizedDescription)")
            errorMessage = "Failed to update follow status"
        }
        
        isFollowingUser = false
    }
    
    /// Load latest comment
    func loadLatestComment() async {
        do {
            let comments = try await engagementService.getComments(postId: post.id)
            
            // Get the most recent comment (last in array, as they're sorted by createdAt ascending)
            latestComment = comments.last
            
            // Load profile for latest comment if it exists
            if let comment = latestComment {
                await loadCommentProfile(userId: comment.userId)
            } else {
                latestCommentProfile = nil
            }
        } catch {
            print("⚠️ PostDetailViewModel: Error loading latest comment: \(error.localizedDescription)")
            latestComment = nil
            latestCommentProfile = nil
        }
    }
    
    /// Load profile for a comment user
    private func loadCommentProfile(userId: String) async {
        do {
            let profile = try await profileService.getUserProfile(userId: userId)
            latestCommentProfile = profile
        } catch {
            print("⚠️ PostDetailViewModel: Error loading comment profile: \(error.localizedDescription)")
            latestCommentProfile = nil
        }
    }
    
    /// Refresh counts and latest comment (call after adding comment)
    func refreshCounts() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadLikeCount() }
            group.addTask { await self.loadCommentCount() }
            group.addTask { await self.loadLatestComment() }
        }
    }
    
    /// Check if current user can follow the post author
    var canFollow: Bool {
        guard let userId = currentUserId else { return false }
        return userId != post.userId
    }
    
    /// Get feed group for comments
    var commentFeedGroup: String {
        return feedGroup
    }
    
    /// Get feed ID for comments
    var commentFeedId: String {
        return feedId
    }
    
    // MARK: - Board Methods
    
    /// Load user's boards
    func loadBoards() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoadingBoards = true
        
        do {
            boards = try await boardService.getUserBoards(userId: userId)
            print("✅ PostDetailViewModel: Loaded \(boards.count) boards")
            
            // Check which boards already contain this post
            let boardIds = boards.compactMap { $0.id }
            if !boardIds.isEmpty {
                boardsContainingPost = try await boardService.getBoardsContainingPost(
                    postId: post.activityId,
                    boardIds: boardIds
                )
                print("✅ PostDetailViewModel: Post is in \(boardsContainingPost.count) boards")
            }
        } catch {
            print("❌ PostDetailViewModel: Error loading boards: \(error.localizedDescription)")
            errorMessage = "Failed to load boards"
        }
        
        isLoadingBoards = false
    }
    
    /// Save post to a board
    func saveToBoard(_ board: Board) async {
        guard let boardId = board.id,
              let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return
        }
        
        isSavingToBoard = true
        errorMessage = nil
        
        do {
            try await boardService.savePostToBoard(
                postId: post.activityId,
                boardId: boardId,
                userId: userId,
                postImageUrl: post.imageUrl
            )
            
            // Track save event with Algolia Insights
            await AlgoliaInsightsService.shared.trackSave(objectID: post.id)
            
            // Update board post count and cover image optimistically
            if let index = boards.firstIndex(where: { $0.id == boardId }) {
                boards[index].postCount += 1
                // Set cover image if board doesn't have one
                if boards[index].coverImageUrl == nil || boards[index].coverImageUrl?.isEmpty == true {
                    boards[index].coverImageUrl = post.imageUrl
                }
            }
            
            // Mark that this board now contains the post
            boardsContainingPost.insert(boardId)
            
            // Close the boards view after successful save
            showBoards = false
            
            print("✅ PostDetailViewModel: Post saved to board \(board.title)")
        } catch {
            print("❌ PostDetailViewModel: Error saving to board: \(error.localizedDescription)")
            errorMessage = "Failed to save to board: \(error.localizedDescription)"
        }
        
        isSavingToBoard = false
    }
    
    // MARK: - Recommendations
    
    /// Load recommended posts based on the current post
    func loadRecommendedPosts() async {
        isLoadingRecommendations = true
        
        do {
            // Get recommendations based on the current post
            let recommendations = try await AlgoliaRecommendService.shared.getRecommendedPosts(
                objectID: post.id,
                limit: 10
            )
            
            // Filter out the current post from recommendations
            recommendedPosts = recommendations.filter { $0.id != post.id }
            
            Logger.info("Loaded \(recommendedPosts.count) recommended posts", service: "PostDetailViewModel")
        } catch {
            Logger.warning("Failed to load recommended posts: \(error.localizedDescription)", service: "PostDetailViewModel")
            recommendedPosts = []
        }
        
        isLoadingRecommendations = false
    }
    
    /// Load related users who create similar content to this post
    func loadRelatedUsers() async {
        isLoadingRelatedUsers = true
        
        do {
            // Get users who create similar content based on the post's tags/categories
            let users = try await userDiscoveryService.getRelatedUsersForPost(post, limit: 10)
            relatedUsers = users
            
            Logger.info("Loaded \(users.count) related users for post", service: "PostDetailViewModel")
        } catch {
            Logger.warning("Failed to load related users: \(error.localizedDescription)", service: "PostDetailViewModel")
            relatedUsers = []
        }
        
        isLoadingRelatedUsers = false
    }
}

