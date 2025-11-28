//
//  StoryServiceProtocol.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
/// Protocol defining the interface for story management operations
@MainActor
protocol StoryServiceProtocol {
    // MARK: - Story Creation
    func createStory(request: CreateStoryRequest) async throws -> Story
    
    // MARK: - Story Retrieval
    func getStoriesForUser(userId: String) async throws -> [Story]
    func getStoriesFromFollowing(userId: String) async throws -> [Story]
    func getStoryItemsForUser(userId: String) async throws -> [StoryItem]
    func getStoryItemsFromFollowing(userId: String) async throws -> [StoryItem]
    
    // MARK: - Story Viewing
    func markStoryAsViewed(storyId: String, userId: String) async throws
    
    // MARK: - Story Management
    func deleteStory(storyId: String) async throws
    func cleanupExpiredStories() async throws
    
    // MARK: - Story Status
    func storyExists(for postId: String, userId: String) async throws -> Bool
}
