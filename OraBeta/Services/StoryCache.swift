//
//  StoryCache.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

class StoryCache: StoryCacheProtocol {
    private let cache = NSCache<NSString, CacheEntry>()
    private let userStoriesCache = NSCache<NSString, UserStoriesEntry>()
    private let logger: StoryLoggingProtocol
    
    // Track keys separately since NSCache doesn't expose allKeys
    private var storyKeys: Set<String> = []
    private var userStoryKeys: Set<String> = []
    private let keysQueue = DispatchQueue(label: "storycache.keys", attributes: .concurrent)
    
    private class CacheEntry {
        let story: Story
        let expiresAt: Date
        
        var isExpired: Bool {
            Date() > expiresAt
        }
        
        init(story: Story, expiresAt: Date) {
            self.story = story
            self.expiresAt = expiresAt
        }
    }
    
    private class UserStoriesEntry {
        let stories: [Story]
        let expiresAt: Date
        
        var isExpired: Bool {
            Date() > expiresAt
        }
        
        init(stories: [Story], expiresAt: Date) {
            self.stories = stories
            self.expiresAt = expiresAt
        }
    }
    
    init(logger: StoryLoggingProtocol = StoryLogger()) {
        self.logger = logger
        
        // Configure cache limits
        cache.countLimit = 100
        userStoriesCache.countLimit = 50
        
        // Clear expired cache every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { _ in
            self.clearExpiredCache()
        }
    }
    
    func getStory(id: String) -> Story? {
        let key = NSString(string: id)
        
        guard let entry = cache.object(forKey: key), !entry.isExpired else {
            cache.removeObject(forKey: key)
            keysQueue.async(flags: .barrier) {
                self.storyKeys.remove(id)
            }
            return nil
        }
        
        logger.logDebug("Cache hit for story: \(id)", category: "Cache")
        return entry.story
    }
    
    func setStory(_ story: Story, ttl: TimeInterval? = nil) {
        let ttl = ttl ?? 5 * 60 // Default 5 minutes
        let key = NSString(string: story.id!)
        let entry = CacheEntry(story: story, expiresAt: Date().addingTimeInterval(ttl))
        
        cache.setObject(entry, forKey: key)
        keysQueue.async(flags: .barrier) {
            self.storyKeys.insert(story.id!)
        }
        logger.logDebug("Cached story: \(story.id!)", category: "Cache")
    }
    
    func removeStory(id: String) {
        let key = NSString(string: id)
        cache.removeObject(forKey: key)
        keysQueue.async(flags: .barrier) {
            self.storyKeys.remove(id)
        }
        logger.logDebug("Removed story from cache: \(id)", category: "Cache")
    }
    
    func getStories(for userId: String) -> [Story]? {
        let key = NSString(string: userId)
        
        guard let entry = userStoriesCache.object(forKey: key), !entry.isExpired else {
            userStoriesCache.removeObject(forKey: key)
            keysQueue.async(flags: .barrier) {
                self.userStoryKeys.remove(userId)
            }
            return nil
        }
        
        logger.logDebug("Cache hit for user stories: \(userId)", category: "Cache")
        return entry.stories
    }
    
    func setStories(_ stories: [Story], for userId: String, ttl: TimeInterval? = nil) {
        let ttl = ttl ?? 3 * 60 // Default 3 minutes for user stories
        let key = NSString(string: userId)
        let entry = UserStoriesEntry(stories: stories, expiresAt: Date().addingTimeInterval(ttl))
        
        userStoriesCache.setObject(entry, forKey: key)
        keysQueue.async(flags: .barrier) {
            self.userStoryKeys.insert(userId)
        }
        logger.logDebug("Cached \(stories.count) stories for user: \(userId)", category: "Cache")
    }
    
    func clearCache() {
        cache.removeAllObjects()
        userStoriesCache.removeAllObjects()
        keysQueue.async(flags: .barrier) {
            self.storyKeys.removeAll()
            self.userStoryKeys.removeAll()
        }
        logger.logInfo("Cleared all story cache", category: "Cache")
    }
    
    func clearExpiredCache() {
        // Clear expired individual stories
        let currentStoryKeys = keysQueue.sync {
            Array(storyKeys)
        }
        
        for storyId in currentStoryKeys {
            let key = NSString(string: storyId)
            if let entry = cache.object(forKey: key), entry.isExpired {
                cache.removeObject(forKey: key)
                keysQueue.async(flags: .barrier) {
                    self.storyKeys.remove(storyId)
                }
            }
        }
        
        // Clear expired user stories
        let currentUserKeys = keysQueue.sync {
            Array(userStoryKeys)
        }
        
        for userId in currentUserKeys {
            let key = NSString(string: userId)
            if let entry = userStoriesCache.object(forKey: key), entry.isExpired {
                userStoriesCache.removeObject(forKey: key)
                keysQueue.async(flags: .barrier) {
                    self.userStoryKeys.remove(userId)
                }
            }
        }
        
        logger.logDebug("Cleared expired cache entries", category: "Cache")
    }
}

// MARK: - Mock Cache for Testing
class MockStoryCache: StoryCacheProtocol {
    private var stories: [String: (story: Story, expiresAt: Date)] = [:]
    private var userStories: [String: (stories: [Story], expiresAt: Date)] = [:]
    
    func getStory(id: String) -> Story? {
        guard let entry = stories[id], Date() <= entry.expiresAt else {
            stories.removeValue(forKey: id)
            return nil
        }
        return entry.story
    }
    
    func setStory(_ story: Story, ttl: TimeInterval? = nil) {
        let ttl = ttl ?? 5 * 60
        stories[story.id!] = (story: story, expiresAt: Date().addingTimeInterval(ttl))
    }
    
    func removeStory(id: String) {
        stories.removeValue(forKey: id)
    }
    
    func getStories(for userId: String) -> [Story]? {
        guard let entry = userStories[userId], Date() <= entry.expiresAt else {
            userStories.removeValue(forKey: userId)
            return nil
        }
        return entry.stories
    }
    
    func setStories(_ stories: [Story], for userId: String, ttl: TimeInterval? = nil) {
        let ttl = ttl ?? 3 * 60
        userStories[userId] = (stories: stories, expiresAt: Date().addingTimeInterval(ttl))
    }
    
    func clearCache() {
        stories.removeAll()
        userStories.removeAll()
    }
    
    func clearExpiredCache() {
        let now = Date()
        
        stories = stories.filter { $0.value.expiresAt > now }
        userStories = userStories.filter { $0.value.expiresAt > now }
    }
}
