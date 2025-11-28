//
//  TopicPreviewService.swift
//  OraBeta
//
//  Service to fetch preview posts for trending topics
//  Uses Algolia to search posts by tag/category - no Firestore indexes needed!
//

import Foundation
import FirebaseAuth

@MainActor
class TopicPreviewService {
    private let algoliaSearchService: AlgoliaSearchService
    
    // Cache for topic previews (topic ID -> posts)
    private var previewCache: [String: [Post]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    init(algoliaSearchService: AlgoliaSearchService? = nil) {
        self.algoliaSearchService = algoliaSearchService ?? AlgoliaSearchService.shared
    }
    
    /// Get preview posts for multiple topics
    /// - Parameters:
    ///   - topics: Array of trending topics
    ///   - limitPerTopic: Number of preview posts per topic (default: 3)
    /// - Returns: Dictionary mapping topic ID to array of Post objects
    func getTopicPreviews(topics: [TrendingTopic], limitPerTopic: Int = 3) async -> [String: [Post]] {
        guard Auth.auth().currentUser != nil else {
            print("⚠️ TopicPreviewService: User not authenticated")
            return [:]
        }
        
        var results: [String: [Post]] = [:]
        
        // Fetch previews for all topics in parallel
        await withTaskGroup(of: (String, [Post]).self) { group in
            for topic in topics {
                group.addTask {
                    let previews = await self.getPreviewForTopic(topic: topic, limit: limitPerTopic)
                    return (topic.id, previews)
                }
            }
            
            for await (topicId, posts) in group {
                results[topicId] = posts
            }
        }
        
        return results
    }
    
    /// Get preview posts for a single topic using Algolia search
    /// - Parameters:
    ///   - topic: Trending topic
    ///   - limit: Number of preview posts to fetch
    /// - Returns: Array of Post objects
    private func getPreviewForTopic(topic: TrendingTopic, limit: Int) async -> [Post] {
        // Check cache first
        if let cached = previewCache[topic.id],
           let timestamp = cacheTimestamp[topic.id],
           Date().timeIntervalSince(timestamp) < cacheExpirationInterval {
            return cached
        }
        
        do {
            print("🖼️ TopicPreviewService: Searching Algolia for topic '\(topic.name)' (type: \(topic.type.rawValue))")
            
            // Use Algolia to search posts by tag/category
            // This is fast, doesn't require Firestore indexes, and uses Algolia's ranking
            let posts = try await algoliaSearchService.searchPostsByTopic(
                topicName: topic.name,
                topicType: topic.type,
                limit: limit
            )
            
            print("✅ TopicPreviewService: Successfully fetched \(posts.count) preview posts for topic '\(topic.name)'")
            
            // Cache results
            previewCache[topic.id] = posts
            cacheTimestamp[topic.id] = Date()
            
            return posts
        } catch {
            // Silently return empty array for preview failures
            // Previews are optional - the UI will work fine without them
            if let algoliaError = error as? AlgoliaSearchError,
               case .notConfigured = algoliaError {
                // Algolia not configured - this is expected in some environments
                return []
            }
            print("⚠️ TopicPreviewService: Failed to fetch previews for topic '\(topic.name)': \(error.localizedDescription)")
            return []
        }
    }
    
    /// Clear cache for a specific topic or all topics
    /// - Parameter topicId: Optional topic ID to clear, or nil to clear all
    func clearCache(topicId: String? = nil) {
        if let topicId = topicId {
            previewCache.removeValue(forKey: topicId)
            cacheTimestamp.removeValue(forKey: topicId)
        } else {
            previewCache.removeAll()
            cacheTimestamp.removeAll()
        }
    }
}

