//
//  HomeFeedViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class HomeFeedViewModel: ObservableObject, PaginatableViewModel {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var isAdmin: Bool = false
    @Published var errorMessage: String?
    @Published var verificationResult: String?
    @Published var isVerifying: Bool = false
    @Published var recommendations: [FollowRecommendation] = []
    @Published var isLoadingRecommendations: Bool = false
    @Published var trendingTopics: [TrendingTopic] = []
    @Published var isLoadingTrendingTopics: Bool = false
    @Published var selectedTrendingTopic: TrendingTopic?
    
    // MARK: - Private Properties
    private let container: DIContainer
    private var feedService: FeedServiceProtocol
    private let trendService: TrendService
    let profileService: ProfileServiceProtocol
    private var currentUserId: String?
    private var lastDocument: QueryDocumentSnapshot?
    let pageSize: Int = 20
    // Debounce for load more requests
    private var lastLoadMoreTime: Date?
    private let loadMoreDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce
    
    // MARK: - Initialization
    init(container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        self.profileService = diContainer.profileService
        self.feedService = diContainer.feedService
        self.trendService = diContainer.trendService
        
        // Ensure HomeFeedViewModel logging is enabled
        LoggingControl.enable("HomeFeedViewModel")
    }
    
    // MARK: - Public Methods
    
    /// Load initial data (posts, admin status, backfill)
    func loadInitialData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot load data - no user ID", service: "HomeFeedViewModel")
            return
        }
        
        currentUserId = userId
        
        // Load posts, admin status, and trending topics in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts() }
            group.addTask { await self.checkIsAdmin() }
            group.addTask { await self.loadPersonalizedTrendingTopics() }
        }
        
        // Run backfill after initial load
        if hasBackfillBeenRun(userId: userId) {
            await verifyAndRetryBackfillIfNeeded(userId: userId)
        } else {
            await runBackfillIfNeeded(userId: userId)
        }
    }
    
    /// Load posts from Firestore (all posts)
    func loadPosts() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot load posts - no user ID", service: "HomeFeedViewModel")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        Logger.info("Loading posts from Firestore", service: "HomeFeedViewModel")
        Logger.debug("User ID: \(userId)", service: "HomeFeedViewModel")
        
        isLoading = true
        errorMessage = nil
        
        // Reset pagination
        lastDocument = nil
        hasMore = true
        
        do {
            // Use FeedService to get posts from Firestore
            let result = try await feedService.getDiscoverFeed(
                userId: userId,
                limit: pageSize,
                strategy: HybridStrategy(recencyWeight: 0.3, popularityWeight: 0.7),
                lastDocument: nil,
                applyRanking: true
            )
            
            posts = result.posts
            lastDocument = result.lastDocument
            
            // If we got fewer posts than requested, there are no more
            hasMore = result.posts.count >= pageSize
            
            // Also check if lastDocument is nil - if so, no more posts
            if result.lastDocument == nil {
                hasMore = false
            }
            
            Logger.info("Loaded \(result.posts.count) posts from Firestore", service: "HomeFeedViewModel")
            Logger.debug("Has more: \(hasMore)", service: "HomeFeedViewModel")
            
            if result.posts.isEmpty {
                Logger.warning("No posts found", service: "HomeFeedViewModel")
                // Load recommendations when feed is empty
                await loadRecommendations()
            } else {
                // Clear recommendations when posts are available
                recommendations = []
            }
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Error loading posts: \(error)", service: "HomeFeedViewModel")
            if let nsError = error as NSError? {
                Logger.debug("Error domain: \(nsError.domain)", service: "HomeFeedViewModel")
                Logger.debug("Error code: \(nsError.code)", service: "HomeFeedViewModel")
                Logger.debug("Error description: \(nsError.localizedDescription)", service: "HomeFeedViewModel")
            }
        }
        
        isLoading = false
    }
    
    /// Handle when a post item appears in the feed (for pagination)
    func onItemAppear(_ post: Post) {
        Logger.info("🔍 onItemAppear called for post: \(post.id)", service: "HomeFeedViewModel")
        
        // Find the index of the post
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else {
            Logger.debug("Post not found in array", service: "HomeFeedViewModel")
            return
        }
        
        // Check if we're near the end (within last 3 posts)
        let threshold = 3
        let distanceFromEnd = posts.count - index - 1
        
        Logger.info("📊 Pagination check - index: \(index), total: \(posts.count), distance: \(distanceFromEnd), threshold: \(threshold)", service: "HomeFeedViewModel")
        
        guard distanceFromEnd <= threshold else {
            Logger.debug("⏸️ Too far from end - need distance <= \(threshold), got \(distanceFromEnd)", service: "HomeFeedViewModel")
            return
        }
        
        Logger.info("✅ Within threshold! Checking states...", service: "HomeFeedViewModel")
        Logger.info("   - isLoadingMore: \(isLoadingMore)", service: "HomeFeedViewModel")
        Logger.info("   - hasMore: \(hasMore)", service: "HomeFeedViewModel")
        Logger.info("   - isLoading: \(isLoading)", service: "HomeFeedViewModel")
        
        // Check if we can load more - CRITICAL: check isLoadingMore BEFORE setting it
        guard !isLoadingMore, hasMore, !isLoading else {
            Logger.warning("❌ Cannot load more - isLoadingMore: \(isLoadingMore), hasMore: \(hasMore), isLoading: \(isLoading)", service: "HomeFeedViewModel")
            return
        }
        
        Logger.info("🚀 All checks passed! Setting isLoadingMore and triggering loadMorePosts()", service: "HomeFeedViewModel")
        
        // CRITICAL FIX: Set isLoadingMore BEFORE creating the Task
        // This prevents race condition where multiple concurrent onItemAppear calls
        // all pass the guard check and create multiple Tasks
        isLoadingMore = true
        
        // Trigger load more (debouncing and actual loading handled in loadMorePosts)
        Task {
            await loadMorePosts()
        }
    }
    
    /// Load more posts (pagination)
    func loadMorePosts() async {
        // Check basic conditions (isLoadingMore already set by onItemAppear)
        guard hasMore, !isLoading else {
            Logger.debug("Cannot load more - hasMore: \(hasMore), isLoading: \(isLoading)", service: "HomeFeedViewModel")
            isLoadingMore = false  // Reset if we can't proceed
            return
        }
        
        // Debounce: Wait if we loaded recently instead of cancelling
        if let lastLoadTime = lastLoadMoreTime {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoadTime)
            if timeSinceLastLoad < loadMoreDebounceInterval {
                let waitTime = loadMoreDebounceInterval - timeSinceLastLoad
                Logger.debug("Debouncing load more request - waiting \(String(format: "%.2f", waitTime))s", service: "HomeFeedViewModel")
                
                // Wait for the remaining time
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot load more posts - no user ID", service: "HomeFeedViewModel")
            return
        }
        
        guard let lastDoc = lastDocument else {
            Logger.warning("Cannot load more - no lastDocument", service: "HomeFeedViewModel")
            hasMore = false
            return
        }
        
        
        // Set debounce time to prevent duplicate calls
        lastLoadMoreTime = Date()
        
        Logger.info("Loading more posts", service: "HomeFeedViewModel")
        Logger.debug("Current post count: \(posts.count)", service: "HomeFeedViewModel")
        
        // isLoadingMore already set to true in onItemAppear()
        
        do {
            let result = try await feedService.getDiscoverFeed(
                userId: userId,
                limit: pageSize,
                strategy: HybridStrategy(recencyWeight: 0.3, popularityWeight: 0.7),
                lastDocument: lastDoc,
                applyRanking: false // Don't re-rank - just append new posts
            )
            
            Logger.info("📦 Received \(result.posts.count) posts from feed service", service: "HomeFeedViewModel")
            
            // Append new posts
            posts.append(contentsOf: result.posts)
            lastDocument = result.lastDocument
            
            // Only set hasMore to false if we got 0 posts (true end of feed)
            // Don't stop just because we got fewer than pageSize - that's not reliable
            if result.posts.isEmpty {
                hasMore = false
                Logger.info("🏁 End of feed reached (0 posts returned)", service: "HomeFeedViewModel")
            } else {
                Logger.info("✅ More posts may be available (got \(result.posts.count) posts)", service: "HomeFeedViewModel")
            }
            
            Logger.info("Loaded \(result.posts.count) more posts", service: "HomeFeedViewModel")
            Logger.debug("Total posts: \(posts.count)", service: "HomeFeedViewModel")
            Logger.debug("Has more: \(hasMore)", service: "HomeFeedViewModel")
        } catch {
            Logger.error("Error loading more posts: \(error)", service: "HomeFeedViewModel")
            hasMore = false
        }
        
        Logger.info("✅ loadMorePosts() completed", service: "HomeFeedViewModel")
        Logger.info("   - Total posts now: \(posts.count)", service: "HomeFeedViewModel")
        Logger.info("   - hasMore: \(hasMore)", service: "HomeFeedViewModel")
        Logger.info("   - isLoadingMore about to be set to false", service: "HomeFeedViewModel")
        
        isLoadingMore = false
    }
    
    /// Trigger load more from footer (explicit trigger)
    func loadMoreTriggered() {
        Logger.info("👇 Footer trigger activated", service: "HomeFeedViewModel")
        
        // Check if we can load more
        guard !isLoadingMore, hasMore, !isLoading else {
            Logger.debug("❌ Cannot load more - isLoadingMore: \(isLoadingMore), hasMore: \(hasMore), isLoading: \(isLoading)", service: "HomeFeedViewModel")
            return
        }
        
        Logger.info("🚀 Triggering loadMorePosts() from footer", service: "HomeFeedViewModel")
        isLoadingMore = true
        
        Task {
            await loadMorePosts()
        }
    }
    
    /// Load follow recommendations
    func loadRecommendations() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot load recommendations - no user ID", service: "HomeFeedViewModel")
            return
        }
        
        Logger.info("Loading follow recommendations", service: "HomeFeedViewModel")
        
        isLoadingRecommendations = true
        
        // Stream functionality removed - return empty recommendations
        recommendations = []
        Logger.info("Recommendations disabled - Stream removed", service: "HomeFeedViewModel")
        isLoadingRecommendations = false
    }
    
    /// Load personalized trending topics for home feed
    func loadPersonalizedTrendingTopics(timeWindow: TrendingTopic.TimeWindow = .days30) async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("Cannot load trending topics - no user ID", service: "HomeFeedViewModel")
            trendingTopics = []
            return
        }
        
        Logger.info("Loading personalized trending topics", service: "HomeFeedViewModel")
        Logger.debug("User ID: \(userId)", service: "HomeFeedViewModel")
        Logger.debug("Time window: \(timeWindow.rawValue)", service: "HomeFeedViewModel")
        
        isLoadingTrendingTopics = true
        
        do {
            let topics = try await trendService.getPersonalizedTrends(
                timeWindow: timeWindow,
                limit: 10
            )
            
            trendingTopics = topics
            Logger.info("Loaded \(topics.count) personalized trending topics", service: "HomeFeedViewModel")
            
            if topics.isEmpty {
                Logger.warning("Trending topics array is empty - no trends available", service: "HomeFeedViewModel")
            } else {
                Logger.debug("Trending topics: \(topics.map { $0.name }.joined(separator: ", "))", service: "HomeFeedViewModel")
            }
        } catch {
            Logger.error("Failed to load trending topics: \(error.localizedDescription)", service: "HomeFeedViewModel")
            if let nsError = error as NSError? {
                Logger.debug("Error domain: \(nsError.domain), code: \(nsError.code)", service: "HomeFeedViewModel")
            }
            trendingTopics = []
        }
        
        isLoadingTrendingTopics = false
    }
    
    /// Filter feed by selected trending topic
    func filterByTrendingTopic(_ topic: TrendingTopic?) async {
        selectedTrendingTopic = topic
        
        guard let topic = topic else {
            // Reset to normal feed
            await loadPosts()
            return
        }
        
        // Load posts for this topic
        isLoading = true
        errorMessage = nil
        
        do {
            let postsData = try await trendService.getPostsByTopic(
                topicId: topic.id,
                topicType: topic.type,
                limit: 20,
                timeWindow: topic.timeWindow
            )
            
            // Convert post dictionaries to Post objects
            var convertedPosts: [Post] = []
            for postData in postsData {
                if let post = await Post.from(firestoreData: postData, documentId: postData["id"] as? String ?? "", profiles: [:]) {
                    convertedPosts.append(post)
                }
            }
            
            self.posts = convertedPosts
            Logger.info("Loaded \(convertedPosts.count) posts for topic \(topic.name)", service: "HomeFeedViewModel")
        } catch {
            errorMessage = "Failed to load posts for topic: \(error.localizedDescription)"
            Logger.error("Failed to load posts by topic: \(error.localizedDescription)", service: "HomeFeedViewModel")
        }
        
        isLoading = false
    }
    
    /// Check if user is admin
    func checkIsAdmin() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return
        }
        
        do {
            isAdmin = try await profileService.isAdmin(userId: userId)
        } catch {
            Logger.warning("Error checking admin status: \(error.localizedDescription)", service: "HomeFeedViewModel")
            isAdmin = false
        }
    }
    
    /// Verify Stream follows and show result
    func verifyFollows() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return
        }
        
        isVerifying = true
        verificationResult = nil
        
        // Stream functionality removed
        verificationResult = "Stream functionality has been removed"
        isVerifying = false
        
        /* Stream code removed
        do {
            let result = try await streamService.verifyStreamFollows(userId: userId)
            
            var message = "Stream Follows Verification\n\n"
            
            if let success = result["success"] as? Bool, success {
                message += "✅ Timeline feed exists\n\n"
                
                if let followingFeeds = result["followingFeeds"] as? [[String: Any]] {
                    message += "Following \(followingFeeds.count) feeds:\n"
                    for feed in followingFeeds.prefix(10) {
                        if let targetFeed = feed["targetFeed"] as? String {
                            message += "  • \(targetFeed)\n"
                        }
                    }
                    if followingFeeds.count > 10 {
                        message += "  ... and \(followingFeeds.count - 10) more\n"
                    }
                    message += "\n"
                }
                
                if let comparison = result["comparison"] as? [String: Any] {
                    let firestoreCount = comparison["firestoreCount"] as? Int ?? 0
                    let streamCount = comparison["streamCount"] as? Int ?? 0
                    let allSynced = comparison["allSynced"] as? Bool ?? false
                    
                    message += "Sync Status:\n"
                    message += "  Firestore: \(firestoreCount) follows\n"
                    message += "  Stream: \(streamCount) follows\n"
                    
                    if allSynced {
                        message += "\n✅ All follows are synced!"
                    } else if let missing = comparison["missingInStream"] as? [String], !missing.isEmpty {
                        message += "\n⚠️ Missing in Stream: \(missing.count) follows\n"
                        for userId in missing.prefix(5) {
                            message += "  • \(userId)\n"
                        }
                        if missing.count > 5 {
                            message += "  ... and \(missing.count - 5) more\n"
                        }
                    }
                }
            } else {
                message += "❌ Verification failed\n\n"
                if let error = result["error"] as? String {
                    message += "Error: \(error)"
                }
            }
            
            verificationResult = message
        } catch {
            verificationResult = "❌ Failed to verify follows\n\nError: \(error.localizedDescription)"
        }
        */
    }
    
    // MARK: - Private Methods
    
    /// Verify feed status when empty
    private func verifyFeedStatus(userId: String) async {
        Logger.warning("Timeline feed is empty", service: "HomeFeedViewModel")
        Logger.debug("This could mean:", service: "HomeFeedViewModel")
        Logger.debug("1. No follows are set up in Stream", service: "HomeFeedViewModel")
        Logger.debug("2. Followed users haven't posted anything yet", service: "HomeFeedViewModel")
        Logger.debug("3. Timeline feed doesn't exist yet", service: "HomeFeedViewModel")
        
        // Stream functionality removed - skip verification
        Logger.info("Stream verification disabled - Stream removed", service: "HomeFeedViewModel")
    }
    
    /// Check if backfill has been run for this user
    private func hasBackfillBeenRun(userId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "streamBackfill_\(userId)")
    }
    
    /// Mark backfill as complete for this user
    private func markBackfillComplete(userId: String) {
        UserDefaults.standard.set(true, forKey: "streamBackfill_\(userId)")
    }
    
    /// Reset backfill flag (for testing or if backfill needs to be rerun)
    private func resetBackfillFlag(userId: String) {
        UserDefaults.standard.removeObject(forKey: "streamBackfill_\(userId)")
        Logger.info("Backfill flag reset for user \(userId)", service: "HomeFeedViewModel")
    }
    
    /// Verify if backfill actually worked and retry if needed
    private func verifyAndRetryBackfillIfNeeded(userId: String) async {
        // Stream functionality removed - skip verification
        Logger.info("Stream backfill verification disabled - Stream removed", service: "HomeFeedViewModel")
    }
    
    /// Run backfill automatically if it hasn't been run yet
    private func runBackfillIfNeeded(userId: String) async {
        // Check if backfill has already been run
        if hasBackfillBeenRun(userId: userId) {
            Logger.info("Backfill already run for user \(userId)", service: "HomeFeedViewModel")
            return
        }
        
        Logger.info("Running automatic backfill for user \(userId)", service: "HomeFeedViewModel")
        
        // Stream functionality removed - skip backfill
        Logger.info("Stream backfill disabled - Stream removed", service: "HomeFeedViewModel")
        return
        
        /* Stream code removed
        // Run backfill in background (non-blocking)
        Task {
            do {
                let result = try await streamService.backfillStreamFollows(
                    userId: userId,
                    includeForyou: false
                )
                
                if let success = result["success"] as? Bool, success {
                    markBackfillComplete(userId: userId)
                    Logger.info("Automatic backfill completed successfully", service: "HomeFeedViewModel")
                    
                    // Refresh feed after backfill to show new posts
                    await loadPosts()
                } else {
                    // Check if there were actual failures vs just warnings vs skipped
                    let failed = result["failed"] as? Int ?? 0
                    let succeeded = result["succeeded"] as? Int ?? 0
                    let processed = result["processed"] as? Int ?? 0
                    let skipped = (result["skipped"] as? [[String: Any]])?.count ?? 0
                    
                    if failed > 0 && succeeded == 0 {
                        // Complete failure - don't mark as complete, allow retry
                        Logger.warning("Backfill failed completely, will retry on next launch", service: "HomeFeedViewModel")
                        Logger.debug("Failed: \(failed), Succeeded: \(succeeded), Processed: \(processed), Skipped: \(skipped)", service: "HomeFeedViewModel")
                    } else if succeeded > 0 {
                        // Partial or full success - mark as complete since some follows were set up
                        markBackfillComplete(userId: userId)
                        Logger.info("Backfill completed - some follows were set up", service: "HomeFeedViewModel")
                        Logger.debug("Failed: \(failed), Succeeded: \(succeeded), Processed: \(processed), Skipped: \(skipped)", service: "HomeFeedViewModel")
                        
                        // Refresh feed to show any new posts
                        await loadPosts()
                    } else if processed > 0 && failed == 0 && succeeded == 0 {
                        // All follows were skipped (target feeds don't exist yet)
                        // This is expected - mark as complete to avoid infinite retries
                        // The follows will be set up automatically when target users post
                        markBackfillComplete(userId: userId)
                        Logger.info("Backfill completed - all follows skipped (target feeds don't exist yet)", service: "HomeFeedViewModel")
                        Logger.debug("Processed: \(processed), Skipped: \(skipped)", service: "HomeFeedViewModel")
                        Logger.debug("Follows will be set up automatically when target users post", service: "HomeFeedViewModel")
                    } else {
                        // No successes, but also no failures processed - might be a different issue
                        Logger.warning("Backfill had issues, will retry on next launch", service: "HomeFeedViewModel")
                        Logger.debug("Failed: \(failed), Succeeded: \(succeeded), Processed: \(processed), Skipped: \(skipped)", service: "HomeFeedViewModel")
                    }
                }
            } catch {
                Logger.warning("Automatic backfill failed (non-critical): \(error.localizedDescription)", service: "HomeFeedViewModel")
                // Don't mark as complete if it failed - will retry on next app launch
            }
        }
        */
    }
}

