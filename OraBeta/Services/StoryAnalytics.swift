//
//  StoryAnalytics.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

class StoryAnalytics: StoryAnalyticsProtocol {
    private let logger: StoryLoggingProtocol
    private let configuration: StoryConfiguration
    
    init(configuration: StoryConfiguration = .default, logger: StoryLoggingProtocol = StoryLogger()) {
        self.configuration = configuration
        self.logger = logger
    }
    
    func track(_ event: StoryAnalyticsEvent) {
        guard configuration.enableAnalytics else { return }
        
        logger.log(event)
        
        // Send to analytics service
        // Analytics.track(event.name, parameters: event.parameters)
    }
    
    func trackStoryCreation(userId: String, postId: String) {
        let event = StoryAnalyticsEvent.storyCreated(userId: userId, postId: postId)
        track(event)
    }
    
    func trackStoryView(storyId: String, userId: String) {
        let event = StoryAnalyticsEvent.storyViewed(storyId: storyId, userId: userId)
        track(event)
    }
    
    func trackStoryDeletion(storyId: String, userId: String) {
        let event = StoryAnalyticsEvent.storyDeleted(storyId: storyId, userId: userId)
        track(event)
    }
    
    func trackError(_ error: StoryError, context: String) {
        let event = StoryAnalyticsEvent.storyError(error: error, context: context)
        track(event)
    }
}

// MARK: - Mock Analytics for Testing
class MockStoryAnalytics: StoryAnalyticsProtocol {
    private(set) var trackedEvents: [StoryAnalyticsEvent] = []
    
    func track(_ event: StoryAnalyticsEvent) {
        trackedEvents.append(event)
    }
    
    func trackStoryCreation(userId: String, postId: String) {
        track(.storyCreated(userId: userId, postId: postId))
    }
    
    func trackStoryView(storyId: String, userId: String) {
        track(.storyViewed(storyId: storyId, userId: userId))
    }
    
    func trackStoryDeletion(storyId: String, userId: String) {
        track(.storyDeleted(storyId: storyId, userId: userId))
    }
    
    func trackError(_ error: StoryError, context: String) {
        track(.storyError(error: error, context: context))
    }
    
    func clear() {
        trackedEvents.removeAll()
    }
}
