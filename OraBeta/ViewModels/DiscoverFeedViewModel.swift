//
//  DiscoverFeedViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class DiscoverFeedViewModel: ObservableObject, PaginatableViewModel {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var suggestedUsers: [UserProfile] = []
    @Published var isLoadingSuggestedUsers: Bool = false
    @Published var trendingInterests: [TrendingInterest] = []
    @Published var featuredInterests: [TrendingInterest] = []
    @Published var interestPreviews: [String: [Post]] = [:]
    @Published var recommendedUsers: [UserProfile] = []
    @Published var isLoadingRecommendedUsers: Bool = false
    @Published var isLoadingTrendingInterests: Bool = false
    @Published var selectedTrendingInterest: TrendingInterest?
    @Published var selectedTimeWindow: String = "7d"
    
    // MARK: - Private Properties
    private let container: DIContainer
    private let feedService: FeedServiceProtocol
    private let interestTaxonomyService: InterestTaxonomyService
    private let userDiscoveryService: UserDiscoveryService
    let profileService: ProfileServiceProtocol
    private var currentUserId: String?
    private var lastDocument: QueryDocumentSnapshot?
    let pageSize: Int = 20 // Expose pageSize for view
    private var currentStrategy: RankingStrategy = HybridStrategy()
    // Track if posts have been loaded to prevent automatic re-ranking
    private var postsLoaded: Bool = false
    // Track if initial data has been loaded to prevent reloading on navigation back
    private var hasLoadedInitialData: Bool = false
    // Store initial post order to prevent re-ranking during scrolling
    private var initialPostOrder: [String] = [] // Array of post IDs in their initial order
    // Debounce for load more requests
    private var lastLoadMoreTime: Date?
    private let loadMoreDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce
    
    // MARK: - Initialization
    init(container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        self.profileService = diContainer.profileService
        self.feedService = diContainer.feedService
        self.interestTaxonomyService = InterestTaxonomyService.shared
        self.userDiscoveryService = diContainer.userDiscoveryService
    }
    
    // MARK: - Public Methods
    
    /// Load initial data (posts and suggested users)
    func loadInitialData() async {
        print("🚀 DiscoverFeedViewModel: loadInitialData() called")
        print("   hasLoadedInitialData: \(hasLoadedInitialData)")
        
        // Only load if we haven't loaded initial data yet
        guard !hasLoadedInitialData else {
            print("📌 DiscoverFeedViewModel: Initial data already loaded, skipping reload")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ DiscoverFeedViewModel: Cannot load data - no user ID")
            return
        }
        
        print("✅ DiscoverFeedViewModel: User authenticated, loading data...")
        currentUserId = userId
        
        // Load posts, suggested users, and trending interests in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts() }
            group.addTask { await self.loadSuggestedUsers() }
            group.addTask { await self.loadTrendingInterests() }
        }
        
        // After trending interests have loaded and featured interests are selected,
        // load preview posts for the hero cards so their images can render.
        if !featuredInterests.isEmpty {
            await loadInterestPreviews()
        }
        
        hasLoadedInitialData = true
        print("✅ DiscoverFeedViewModel: loadInitialData() completed")
    }
    
    /// Load posts from discover feed (resets pagination)
    /// This will re-rank posts based on current metrics, so order may change
    func loadPosts() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ DiscoverFeedViewModel: Cannot load posts - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        print("🔄 DiscoverFeedViewModel: Loading posts from discover feed")
        print("   User ID: \(userId)")
        print("   Strategy: \(currentStrategy.name)")
        
        // Reset pagination
        lastDocument = nil
        hasMore = true
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await feedService.getDiscoverFeed(
                userId: userId,
                limit: pageSize,
                strategy: currentStrategy,
                lastDocument: nil,
                applyRanking: true
            )
            
            // Replace all posts with newly fetched and ranked posts
            // Store the initial order of post IDs to maintain stability
            // Use atomic update to prevent intermediate SwiftUI re-renders
            let newPosts = result.posts
            let newOrder = newPosts.map { $0.id }
            
            // Atomic update: replace entire array at once
            // This prevents SwiftUI from seeing intermediate states
            self.posts = newPosts
            self.initialPostOrder = newOrder
            self.lastDocument = result.lastDocument
            self.postsLoaded = true
            
            print("📌 DiscoverFeedViewModel: Posts array updated - order locked (will not change until next refresh)")
            print("   Initial post order: \(newOrder.prefix(5).joined(separator: ", "))...")
            print("   Total posts: \(newPosts.count)")
            print("   Last document exists: \(result.lastDocument != nil)")
            
            // If we got fewer posts than requested, there are no more
            hasMore = result.posts.count >= pageSize
            
            // Also check if lastDocument is nil - if so, no more posts
            if result.lastDocument == nil {
                hasMore = false
                print("   Last document is nil - setting hasMore to false")
            }
            
            print("✅ DiscoverFeedViewModel: Loaded \(result.posts.count) posts from discover feed")
            print("   Has more: \(hasMore)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DiscoverFeedViewModel: Error loading posts: \(error)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error description: \(nsError.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    /// Trigger load more from footer (explicit trigger)
    func loadMoreTriggered() {
        print("👇 Footer trigger activated (DiscoverFeedViewModel)")
        
        // Check if we can load more
        guard !isLoadingMore, hasMore, !isLoading else {
            print("❌ Cannot load more - isLoadingMore: \(isLoadingMore), hasMore: \(hasMore), isLoading: \(isLoading)")
            return
        }
        
        print("🚀 Triggering loadMorePosts() from footer")
        isLoadingMore = true
        
        Task {
            await loadMorePosts()
        }
    }
    
    /// Load more posts (pagination)
    /// Note: New posts are appended without re-ranking existing posts
    /// This ensures the feed order remains stable during scrolling
    func loadMorePosts() async {
        // Don't load more if already loading or no more available
        // Note: We check isLoadingMore here, but it might be true if called from loadMoreTriggered
        // That's fine, we just want to ensure we don't run multiple loadMorePosts concurrently
        // But since this is async, we need to be careful.
        // The check in loadMoreTriggered handles the UI trigger.
        // If called directly, we should check.
        
        // Basic guard for state
        guard hasMore else {
            print("⚠️ DiscoverFeedViewModel: Cannot load more - hasMore is false")
            return
        }
        
        // Debounce: Wait if we loaded recently instead of cancelling
        if let lastLoadTime = lastLoadMoreTime {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoadTime)
            if timeSinceLastLoad < loadMoreDebounceInterval {
                let waitTime = loadMoreDebounceInterval - timeSinceLastLoad
                print("⏸️ DiscoverFeedViewModel: Debouncing load more request - waiting \(String(format: "%.2f", waitTime))s")
                
                // Wait for the remaining time
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ DiscoverFeedViewModel: Cannot load more posts - no user ID")
            return
        }
        
        // Set debounce time to prevent duplicate calls
        lastLoadMoreTime = Date()
        
        // Regular discover feed pagination
        guard let lastDoc = lastDocument else {
            print("⚠️ DiscoverFeedViewModel: Cannot load more - no lastDocument")
            print("   Current post count: \(posts.count)")
            print("   This might mean we've reached the end or initial load didn't set lastDocument")
            hasMore = false
            return
        }
        
        print("🔄 DiscoverFeedViewModel: Loading more posts")
        print("   Current post count: \(posts.count)")
        print("   Last document exists: \(lastDoc != nil)")
        print("   Last document ID: \(lastDoc.documentID)")
        print("   Page size: \(pageSize)")
        
        isLoadingMore = true
        
        do {
            // Fetch new posts WITHOUT applying ranking to prevent re-ordering
            // New posts will be appended in Firestore order (createdAt descending)
            // This ensures existing posts maintain their order
            let result = try await feedService.getDiscoverFeed(
                userId: userId,
                limit: pageSize,
                strategy: currentStrategy,
                lastDocument: lastDoc,
                applyRanking: false // Don't re-rank - just append new posts
            )
            
            // Append new posts without re-ranking existing ones
            // This ensures the feed order remains stable during scrolling
            // Atomic update: create new array with existing + new posts
            let newPosts = result.posts
            let newPostIds = newPosts.map { $0.id }
            let updatedPosts = self.posts + newPosts
            let updatedOrder = self.initialPostOrder + newPostIds
            
            // Atomic update: replace entire array at once
            // This prevents SwiftUI from seeing intermediate states
            self.posts = updatedPosts
            self.initialPostOrder = updatedOrder
            self.lastDocument = result.lastDocument
            
            print("📌 DiscoverFeedViewModel: Appended \(newPosts.count) posts - existing order preserved (no re-ranking)")
            print("   Previous count: \(updatedPosts.count - newPosts.count), New count: \(updatedPosts.count)")
            
            // If we got fewer posts than requested, there are no more
            hasMore = result.posts.count >= pageSize
            
            print("✅ DiscoverFeedViewModel: Loaded \(result.posts.count) more posts")
            print("   Total posts: \(posts.count)")
            print("   Has more: \(hasMore)")
            print("   Last document exists: \(result.lastDocument != nil)")
            
            // If we got 0 posts, definitely no more
            if result.posts.isEmpty {
                hasMore = false
                print("   No posts returned - setting hasMore to false")
            }
        } catch {
            print("❌ DiscoverFeedViewModel: Error loading more posts: \(error)")
            // Don't set errorMessage for pagination failures to avoid disrupting the UI
            hasMore = false
        }
        
        isLoadingMore = false
    }
    
    
    /// Set ranking strategy and reload feed
    func setRankingStrategy(_ strategy: RankingStrategy) {
        currentStrategy = strategy
        Task {
            await loadPosts()
        }
    }
    
    /// Load suggested users for discover feed
    func loadSuggestedUsers() async {
        guard currentUserId ?? Auth.auth().currentUser?.uid != nil else {
            print("⚠️ DiscoverFeedViewModel: Cannot load suggested users - no user ID")
            return
        }
        
        print("👥 DiscoverFeedViewModel: Loading suggested users")
        
        isLoadingSuggestedUsers = true
        
        do {
            // Use UserDiscoveryService to get recommended users
            // This combines popular, similar interests, and recently active users
            let users = try await userDiscoveryService.getRecommendedUsers(limit: 10)
            suggestedUsers = users
            print("✅ DiscoverFeedViewModel: Loaded \(users.count) suggested users")
        } catch {
            print("⚠️ DiscoverFeedViewModel: Failed to load suggested users: \(error.localizedDescription)")
            suggestedUsers = []
        }
        
        isLoadingSuggestedUsers = false
    }
    
    /// Load recommended users for discover feed
    func loadRecommendedUsers() async {
        guard currentUserId ?? Auth.auth().currentUser?.uid != nil else {
            print("⚠️ DiscoverFeedViewModel: Cannot load recommended users - no user ID")
            return
        }
        
        isLoadingRecommendedUsers = true
        
        do {
            // Use UserDiscoveryService to get recommended users
            // This combines popular, similar interests, and recently active users
            let users = try await userDiscoveryService.getRecommendedUsers(limit: 10)
            recommendedUsers = users
            print("✅ DiscoverFeedViewModel: Loaded \(users.count) recommended users")
        } catch {
            print("⚠️ DiscoverFeedViewModel: Failed to load recommended users: \(error.localizedDescription)")
            recommendedUsers = []
        }
        
        isLoadingRecommendedUsers = false
    }
    
    /// Load interest previews for featured interests
    func loadInterestPreviews() async {
        guard !featuredInterests.isEmpty else { return }
        
        let interestPreviewService = InterestPreviewService()
        let remotePreviews = await interestPreviewService.getInterestPreviews(
            interests: featuredInterests,
            limitPerInterest: 3
        )
        
        // Fallback: if no remote results for an interest,
        // synthesize previews from the posts already loaded in the discover feed.
        var combinedPreviews: [String: [Post]] = [:]
        
        for interest in featuredInterests {
            let remote = remotePreviews[interest.id] ?? []
            if !remote.isEmpty {
                combinedPreviews[interest.id] = Array(remote.prefix(3))
            } else {
                let local = getLocalPreviewPosts(for: interest, limit: 3)
                if !local.isEmpty {
                    combinedPreviews[interest.id] = local
                }
            }
        }
        
        interestPreviews = combinedPreviews
    }
    
    /// Build preview posts for an interest from the already loaded discover posts.
    /// This is used when remote previews are unavailable.
    private func getLocalPreviewPosts(for interest: TrendingInterest, limit: Int) -> [Post] {
        guard !posts.isEmpty else { return [] }
        
        let interestId = interest.id.lowercased()
        
        let matchingPosts: [Post] = posts.filter { post in
            // Match on interest IDs
            let interests = (post.interestIds ?? []).map { $0.lowercased() }
            return interests.contains(interestId)
        }
        
        return Array(matchingPosts.prefix(limit))
    }
    
    /// Load trending interests for discover feed
    func loadTrendingInterests(timeWindow: String? = nil) async {
        guard currentUserId ?? Auth.auth().currentUser?.uid != nil else {
            print("⚠️ DiscoverFeedViewModel: Cannot load trending interests - no user ID")
            return
        }
        
        let window = timeWindow ?? selectedTimeWindow
        
        print("📈 DiscoverFeedViewModel: Loading trending interests (timeWindow: \(window))")
        
        isLoadingTrendingInterests = true
        
        do {
            // Convert string to enum
            let timeWindowEnum: TrendingInterest.TimeWindow
            switch window {
            case "24h":
                timeWindowEnum = .hours24
            case "7d":
                timeWindowEnum = .days7
            case "30d":
                timeWindowEnum = .days30
            default:
                timeWindowEnum = .days7
            }
            
            let interests = try await interestTaxonomyService.getTrendingInterests(
                timeWindow: timeWindowEnum,
                limit: 15
            )
            
            trendingInterests = interests
            print("✅ DiscoverFeedViewModel: Loaded \(interests.count) trending interests")
            
            // Select featured interests (top 3 by trend score)
            selectFeaturedInterests()
        } catch {
            print("⚠️ DiscoverFeedViewModel: Failed to load trending interests: \(error.localizedDescription)")
            trendingInterests = []
        }
        
        isLoadingTrendingInterests = false
    }
    
    /// Select featured interests from trending interests (top 3 by trend score)
    func selectFeaturedInterests() {
        featuredInterests = Array(trendingInterests.sorted { $0.trendScore > $1.trendScore }.prefix(3))
        print("✅ DiscoverFeedViewModel: Selected \(featuredInterests.count) featured interests")
    }
    
    /// Change time window and reload trending interests
    func changeTimeWindow(_ timeWindow: String) async {
        selectedTimeWindow = timeWindow
        await loadTrendingInterests(timeWindow: timeWindow)
    }
    
    /// Perform search (placeholder for future implementation)
    func performSearch() async {
        guard !searchText.isEmpty else {
            isSearching = false
            await loadPosts()
            return
        }
        
        isSearching = true
        isLoading = true
        errorMessage = nil
        
        // Reset pagination when searching
        lastDocument = nil
        hasMore = false // Disable pagination during search
        
        // TODO: Implement search via Firebase Functions
        // For now, clear results to show search UI is working
        // When search is implemented, replace this with actual search logic
        posts = []
        
        // Simulate search delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isLoading = false
    }
    
    /// Handle search text changes
    func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            // When search is cleared, show discover feed
            isSearching = false
            Task {
                await loadPosts()
            }
        } else {
            // Mark as searching when text is entered
            isSearching = true
        }
    }
}

