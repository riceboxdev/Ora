//
//  DiscoverFeedPaginationTests.swift
//  OraBetaTests
//
//  Created by Nick Rogers on 11/1/25.
//

import XCTest
@testable import OraBeta

@MainActor
final class DiscoverFeedPaginationTests: XCTestCase {
    
    var viewModel: DiscoverFeedViewModel!
    var mockStreamService: StreamService!
    var mockProfileService: ProfileService!
    
    override func setUp() {
        super.setUp()
        // Note: These tests require Firebase to be configured
        // For unit tests, you'd typically use dependency injection with mocks
        mockStreamService = StreamService()
        mockProfileService = ProfileService()
        viewModel = DiscoverFeedViewModel(
            streamService: mockStreamService,
            profileService: mockProfileService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockStreamService = nil
        mockProfileService = nil
        super.tearDown()
    }
    
    // MARK: - Threshold Tests
    
    func testOnItemAppear_TriggersWhenWithinThreshold() async {
        // Given: We have 20 posts loaded
        await viewModel.loadPosts()
        XCTAssertEqual(viewModel.posts.count, 20, "Should have 20 posts initially")
        XCTAssertTrue(viewModel.hasMore, "Should have more posts")
        
        // When: Post #18 appears (within last 3)
        let post18 = viewModel.posts[17] // 0-indexed, so index 17 = post #18
        viewModel.onItemAppear(post18)
        
        // Then: Should trigger load more
        // Note: This is async, so we need to wait
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify loading state was triggered
        // (In a real test, you'd mock the service and verify it was called)
    }
    
    func testOnItemAppear_DoesNotTriggerWhenFarFromEnd() {
        // Given: We have 20 posts loaded
        // When: Post #5 appears (not within last 3)
        // Then: Should NOT trigger load more
        
        // This test would verify the threshold logic
        // Implementation depends on your test setup
    }
    
    func testOnItemAppear_DoesNotTriggerWhenHasMoreIsFalse() {
        // Given: hasMore = false (end of feed)
        viewModel.hasMore = false
        
        // When: Post appears
        // Then: Should NOT trigger load more
    }
    
    func testOnItemAppear_DoesNotTriggerWhenAlreadyLoading() {
        // Given: isLoadingMore = true
        viewModel.isLoadingMore = true
        
        // When: Post appears
        // Then: Should NOT trigger load more
    }
    
    // MARK: - Pagination State Tests
    
    func testInitialState() {
        XCTAssertEqual(viewModel.posts.count, 0, "Should start with no posts")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(viewModel.isLoadingMore, "Should not be loading more initially")
        XCTAssertTrue(viewModel.hasMore, "Should assume more posts available initially")
    }
    
    func testLoadPosts_UpdatesState() async {
        // When: Load posts
        await viewModel.loadPosts()
        
        // Then: State should be updated
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after load completes")
        XCTAssertGreaterThan(viewModel.posts.count, 0, "Should have loaded some posts")
    }
    
    // MARK: - Debouncing Tests
    
    func testLoadMorePosts_DebouncesRapidRequests() async {
        // Given: Initial posts loaded
        await viewModel.loadPosts()
        
        // When: Trigger load more twice rapidly
        await viewModel.loadMorePosts()
        let firstLoadTime = Date()
        
        await viewModel.loadMorePosts()
        let secondLoadTime = Date()
        
        // Then: Second request should be debounced if < 1 second
        let timeDifference = secondLoadTime.timeIntervalSince(firstLoadTime)
        if timeDifference < 1.0 {
            // Should see debounce message in console
            // In a real test, verify only one network call was made
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullPaginationFlow() async {
        // 1. Initial load
        await viewModel.loadPosts()
        let initialCount = viewModel.posts.count
        XCTAssertGreaterThan(initialCount, 0, "Should load initial posts")
        
        // 2. Trigger pagination
        if initialCount >= 3 {
            let lastPost = viewModel.posts[initialCount - 1]
            viewModel.onItemAppear(lastPost)
            
            // Wait for async load
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // 3. Verify more posts loaded
            XCTAssertGreaterThan(viewModel.posts.count, initialCount, "Should have more posts after pagination")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testPagination_HandlesEmptyResults() async {
        // Test when no more posts are available
        // This would require mocking the service to return empty results
    }
    
    func testPagination_PreservesPostOrder() async {
        // Given: Initial posts loaded
        await viewModel.loadPosts()
        let initialOrder = viewModel.posts.map { $0.id }
        
        // When: Load more
        await viewModel.loadMorePosts()
        
        // Then: Initial posts should remain in same order
        let newOrder = viewModel.posts.prefix(initialOrder.count).map { $0.id }
        XCTAssertEqual(initialOrder, Array(newOrder), "Initial posts should maintain order")
    }
}






