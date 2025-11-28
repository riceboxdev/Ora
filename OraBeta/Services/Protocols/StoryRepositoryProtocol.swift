//
//  StoryRepositoryProtocol.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

/// Protocol defining the interface for story data access operations
protocol StoryRepositoryProtocol {
    func create(_ story: Story) async throws -> Story
    func fetchStory(id: String) async throws -> Story?
    func fetchStories(for userId: String, limit: Int?, after: Story?) async throws -> [Story]
    func fetchActiveStories(for userIds: [String]) async throws -> [Story]
    func update(_ story: Story) async throws -> Story
    func delete(id: String) async throws
    func fetchExpiredStories(before date: Date) async throws -> [Story]
    func markAsViewed(storyId: String, userId: String) async throws
    func storyExists(postId: String, userId: String) async throws -> Bool
}

// MARK: - Story Cache Protocol
protocol StoryCacheProtocol {
    func getStory(id: String) -> Story?
    func setStory(_ story: Story, ttl: TimeInterval?)
    func removeStory(id: String)
    func getStories(for userId: String) -> [Story]?
    func setStories(_ stories: [Story], for userId: String, ttl: TimeInterval?)
    func clearCache()
    func clearExpiredCache()
}

// MARK: - Story Analytics Protocol
protocol StoryAnalyticsProtocol {
    func track(_ event: StoryAnalyticsEvent)
    func trackStoryCreation(userId: String, postId: String)
    func trackStoryView(storyId: String, userId: String)
    func trackStoryDeletion(storyId: String, userId: String)
    func trackError(_ error: StoryError, context: String)
}
