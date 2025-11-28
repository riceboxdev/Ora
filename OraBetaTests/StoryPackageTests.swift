//
//  StoryPackageTests.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import Testing
import FirebaseFirestore

// MARK: - Mock Cache for Testing (unique name to avoid ambiguity)
class MockStoryCacheForTests: StoryCacheProtocol {
    var getStoryResult: Story? = nil
    var getStoriesResult: [Story]? = nil
    
    var getStoryCallCount = 0
    var setStoryCallCount = 0
    var removeStoryCallCount = 0
    var getStoriesCallCount = 0
    var setStoriesCallCount = 0
    var clearCacheCallCount = 0
    var clearExpiredCacheCallCount = 0
    
    func getStory(id: String) -> Story? {
        getStoryCallCount += 1
        return getStoryResult
    }
    
    func setStory(_ story: Story, ttl: TimeInterval?) {
        setStoryCallCount += 1
    }
    
    func removeStory(id: String) {
        removeStoryCallCount += 1
    }
    
    func getStories(for userId: String) -> [Story]? {
        getStoriesCallCount += 1
        return getStoriesResult
    }
    
    func setStories(_ stories: [Story], for userId: String, ttl: TimeInterval?) {
        setStoriesCallCount += 1
    }
    
    func clearCache() {
        clearCacheCallCount += 1
    }
    
    func clearExpiredCache() {
        clearExpiredCacheCallCount += 1
    }
}

// MARK: - Story Service Tests
@Suite("Story Service Tests")
struct StoryServiceTests {
    private var mockRepository: MockStoryRepository
    private var mockCache: MockStoryCacheForTests
    private var mockAnalytics: MockStoryAnalytics
    private var mockLogger: MockStoryLogger
    private var mockProfileService: MockProfileServiceForTests
    private var mockPostService: MockPostServiceForTests
    private var storyService: EnhancedStoryService
    
    init() {
        mockRepository = MockStoryRepository()
        mockCache = MockStoryCacheForTests()
        mockAnalytics = MockStoryAnalytics()
        mockLogger = MockStoryLogger()
        mockProfileService = MockProfileServiceForTests()
        mockPostService = MockPostServiceForTests()
        
        let config = StoryConfiguration.development
        storyService = EnhancedStoryService(
            configuration: config,
            repository: mockRepository,
            cache: mockCache,
            analytics: mockAnalytics,
            logger: mockLogger,
            profileService: mockProfileService,
            postService: mockPostService
        )
    }
    
    @Test("Create story successfully")
    func createStorySuccess() async throws {
        // Given
        let request = CreateStoryRequest(postId: "post1", userId: "user1")
        let expectedStory = Story(userId: "user1", postId: "post1")
        mockRepository.createResult = Result<Story, StoryError>.success(expectedStory)
        mockPostService.getPostResult = Post.samplePost
        
        // When
        let result = try await storyService.createStory(request: request)
        
        // Then
        #expect(result.userId == "user1")
        #expect(result.postId == "post1")
        #expect(mockRepository.createCallCount == 1)
        #expect(mockAnalytics.trackedEvents.count == 1)
        #expect(mockAnalytics.trackedEvents.first?.name == "story_created")
    }
    
    @Test("Create story fails for duplicate")
    func createStoryFailsForDuplicate() async throws {
        // Given
        let request = CreateStoryRequest(postId: "post1", userId: "user1")
        mockRepository.storyExistsResult = true
        mockPostService.getPostResult = Post.samplePost
        
        // When & Then
        do {
            _ = try await storyService.createStory(request: request)
            #expect(Bool(false), "Expected error to be thrown")
        } catch StoryError.duplicateResource {
            // Expected
        } catch {
            #expect(Bool(false), "Expected duplicateResource error, got \(error)")
        }
    }
    
    @Test("Get stories for user uses cache")
    func getStoriesForUserUsesCache() async throws {
        // Given
        let userId = "user1"
        let cachedStories = [Story(userId: userId, postId: "post1")]
        mockCache.getStoriesResult = cachedStories
        
        // When
        let result = try await storyService.getStoriesForUser(userId: userId)
        
        // Then
        #expect(result.count == 1)
        #expect(mockCache.getStoriesCallCount == 1)
        #expect(mockRepository.fetchStoriesCallCount == 0) // Should not call repository
    }
    
    @Test("Mark story as viewed")
    func markStoryAsViewed() async throws {
        // Given
        let storyId = "story1"
        let userId = "user1"
        
        // When
        try await storyService.markStoryAsViewed(storyId: storyId, userId: userId)
        
        // Then
        #expect(mockRepository.markAsViewedCallCount == 1)
        #expect(mockCache.removeStoryCallCount == 1)
        #expect(mockAnalytics.trackedEvents.count == 1)
        #expect(mockAnalytics.trackedEvents.first?.name == "story_viewed")
    }
}

// MARK: - Story ViewModel Tests
@Suite("Story ViewModel Tests")
struct StoryViewModelTests {
    private var mockStoryService: MockStoryService
    private var viewModel: StoryViewModel
    
    init() {
        mockStoryService = MockStoryService()
        viewModel = StoryViewModel(storyService: mockStoryService)
    }
    
    @Test("Load stories success")
    func loadStoriesSuccess() async {
        // Given
        let expectedStories = [StoryItem.sampleStory]
        mockStoryService.getStoryItemsFromFollowingResult = expectedStories
        mockStoryService.getStoryItemsForUserResult = []
        
        // When
        await viewModel.loadStories()
        
        // Then
        #expect(viewModel.storyItems.count == 1)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.hasError)
    }
    
    @Test("Create story success")
    func createStorySuccess() async {
        // Given
        let post = Post.samplePost
        mockStoryService.createStoryResult = Result<Story, StoryError>.success(Story(userId: "user1", postId: post.id))
        
        // When
        let result = await viewModel.createStory(from: post)
        
        // Then
        #expect(result)
        #expect(!viewModel.hasError)
    }
    
    @Test("Create story failure")
    func createStoryFailure() async {
        // Given
        let post = Post.samplePost
        mockStoryService.createStoryResult = Result<Story, StoryError>.failure(StoryError.validationError("Invalid user"))
        
        // When
        let result = await viewModel.createStory(from: post)
        
        // Then
        #expect(!result)
        #expect(viewModel.hasError)
        #expect(viewModel.error?.errorDescription == "Validation error: Invalid user")
    }
}

// MARK: - Mock Objects for Testing
class MockStoryRepository: StoryRepositoryProtocol {
    var createResult: StoryResult<Story> = .failure(StoryError.unknownError("Not set"))
    var fetchStoryResult: Story? = nil
    var fetchStoriesResult: [Story] = []
    var fetchActiveStoriesResult: [Story] = []
    var updateResult: StoryResult<Story> = .failure(StoryError.unknownError("Not set"))
    var fetchExpiredStoriesResult: [Story] = []
    var storyExistsResult = false
    
    var createCallCount = 0
    var fetchStoryCallCount = 0
    var fetchStoriesCallCount = 0
    var fetchActiveStoriesCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var fetchExpiredStoriesCallCount = 0
    var markAsViewedCallCount = 0
    var storyExistsCallCount = 0
    
    func create(_ story: Story) async throws -> Story {
        createCallCount += 1
        switch createResult {
        case .success(let story):
            return story
        case .failure(let error):
            throw error
        }
    }
    
    func fetchStory(id: String) async throws -> Story? {
        fetchStoryCallCount += 1
        return fetchStoryResult
    }
    
    func fetchStories(for userId: String, limit: Int?, after: Story?) async throws -> [Story] {
        fetchStoriesCallCount += 1
        return fetchStoriesResult
    }
    
    func fetchActiveStories(for userIds: [String]) async throws -> [Story] {
        fetchActiveStoriesCallCount += 1
        return fetchActiveStoriesResult
    }
    
    func update(_ story: Story) async throws -> Story {
        updateCallCount += 1
        switch updateResult {
        case .success(let story):
            return story
        case .failure(let error):
            throw error
        }
    }
    
    func delete(id: String) async throws {
        deleteCallCount += 1
    }
    
    func fetchExpiredStories(before date: Date) async throws -> [Story] {
        fetchExpiredStoriesCallCount += 1
        return fetchExpiredStoriesResult
    }
    
    func markAsViewed(storyId: String, userId: String) async throws {
        markAsViewedCallCount += 1
    }
    
    func storyExists(postId: String, userId: String) async throws -> Bool {
        storyExistsCallCount += 1
        return storyExistsResult
    }
}

class MockStoryService: StoryServiceProtocol {
    var createStoryResult: StoryResult<Story> = .failure(StoryError.unknownError("Not set"))
    var getStoriesForUserResult: [Story] = []
    var getStoriesFromFollowingResult: [Story] = []
    var getStoryItemsForUserResult: [StoryItem] = []
    var getStoryItemsFromFollowingResult: [StoryItem] = []
    var storyExistsResult = false
    
    func createStory(request: CreateStoryRequest) async throws -> Story {
        switch createStoryResult {
        case .success(let story):
            return story
        case .failure(let error):
            throw error
        }
    }
    
    func getStoriesForUser(userId: String) async throws -> [Story] {
        return getStoriesForUserResult
    }
    
    func getStoriesFromFollowing(userId: String) async throws -> [Story] {
        return getStoriesFromFollowingResult
    }
    
    func getStoryItemsForUser(userId: String) async throws -> [StoryItem] {
        return getStoryItemsForUserResult
    }
    
    func getStoryItemsFromFollowing(userId: String) async throws -> [StoryItem] {
        return getStoryItemsFromFollowingResult
    }
    
    func markStoryAsViewed(storyId: String, userId: String) async throws {
        // Mock implementation
    }
    
    func deleteStory(storyId: String) async throws {
        // Mock implementation
    }
    
    func cleanupExpiredStories() async throws {
        // Mock implementation
    }
    
    func storyExists(for postId: String, userId: String) async throws -> Bool {
        return storyExistsResult
    }
}

class MockProfileServiceForTests: ProfileServiceProtocol {
    func getUserProfile(userId: String) async throws -> UserProfile? {
        return FakeUsers.users.first
    }
    
    func getUserProfiles(userIds: [String]) async throws -> [String: UserProfile] {
        var result: [String: UserProfile] = [:]
        for user in FakeUsers.users.prefix(userIds.count) {
            result[user.id ?? ""] = user
        }
        return result
    }
    
    func clearCache(userId: String?) {
        // Mock implementation
    }
    
    func getCurrentUserProfile() async throws -> UserProfile? {
        return FakeUsers.users.first
    }
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        // Mock implementation
    }
    
    func updateProfile(userId: String, fields: [String: Any]) async throws {
        // Mock implementation
    }
    
    func createProfileFromAuthUser(email: String, displayName: String?) async throws {
        // Mock implementation
    }
    
    func isAdmin(userId: String) async throws -> Bool {
        return false
    }
    
    func profileExists() async throws -> Bool {
        return true
    }
    
    func createProfileForCurrentUser() async throws {
        // Mock implementation
    }
    
    func followUser(followingId: String) async throws {
        // Mock implementation
    }
    
    func unfollowUser(followingId: String) async throws {
        // Mock implementation
    }
    
    func isFollowing(followingId: String) async throws -> Bool {
        return false
    }
    
    func checkUsernameAvailability(username: String) async throws -> Bool {
        return true
    }
    
    func completeOnboarding(
        userId: String,
        username: String,
        bio: String?,
        profilePhotoUrl: String?
    ) async throws {
        // Mock implementation
    }
}

class MockPostServiceForTests: PostServiceProtocol {
    var getPostResult: Post? = nil
    
    func createPost(
        userId: String,
        imageUrl: String,
        thumbnailUrl: String?,
        imageWidth: Int?,
        imageHeight: Int?,
        caption: String?,
        tags: [String]?,
        categories: [String]?
    ) async throws -> String {
        throw StoryError.serviceUnavailable("Not implemented in mock")
    }
    
    func editPost(
        postId: String,
        caption: String?,
        tags: [String]?,
        categories: [String]?
    ) async throws {
        // Mock implementation
    }
    
    func getPosts(
        userId: String?,
        limit: Int,
        lastDocument: QueryDocumentSnapshot?
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?) {
        if let post = getPostResult {
            return ([post], nil)
        }
        return ([], nil)
    }
    
    func deletePost(postId: String) async throws {
        // Mock implementation
    }
    
    func removeTagFromAllPosts(_ tagToRemove: String) async throws -> (updatedCount: Int, errorCount: Int) {
        return (0, 0)
    }
    
    func deletePostsWithoutTags() async throws -> (deletedCount: Int, errorCount: Int) {
        return (0, 0)
    }
}

// MARK: - Test Utilities
extension StoryServiceTests {
    func createTestStory() -> Story {
        return Story(userId: "test_user", postId: "test_post")
    }
    
    func createTestStoryItem() -> StoryItem {
        let story = createTestStory()
        let post = Post.samplePost
        let user = FakeUsers.users[0]
        
        return StoryItem(
            id: story.id!,
            story: story,
            post: post,
            user: user
        )
    }
}
