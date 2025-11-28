//
//  PersonalizedTopicStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Ranking strategy that prioritizes posts based on personalized trending topics and user preferences
struct PersonalizedTopicStrategy: RankingStrategy {
    var name: String {
        return "personalized_topic_ranking"
    }
    
    let trendingTopics: [TrendingTopic] // Personalized trending topics
    let userPreferences: UserTopicPreferences? // User's preference weights
    let topicWeight: Double // Weight for topic relevance
    let recencyWeight: Double // Weight for recency
    let popularityWeight: Double // Weight for popularity
    
    struct UserTopicPreferences {
        let preferredLabels: Set<String>
        let preferredTags: Set<String>
        let preferredCategories: Set<String>
        let labelWeights: [String: Double]
        let tagWeights: [String: Double]
        let categoryWeights: [String: Double]
    }
    
    init(
        trendingTopics: [TrendingTopic] = [],
        userPreferences: UserTopicPreferences? = nil,
        topicWeight: Double = 0.4,
        recencyWeight: Double = 0.3,
        popularityWeight: Double = 0.3
    ) {
        self.trendingTopics = trendingTopics
        self.userPreferences = userPreferences
        self.topicWeight = topicWeight
        self.recencyWeight = recencyWeight
        self.popularityWeight = popularityWeight
    }
    
    func rank(posts: [Post], for userId: String?) -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        // If no trending topics and no preferences, fall back to hybrid strategy
        if trendingTopics.isEmpty && userPreferences == nil {
            let hybridStrategy = HybridStrategy(recencyWeight: recencyWeight, popularityWeight: popularityWeight + topicWeight)
            return hybridStrategy.rank(posts: posts, for: userId)
        }
        
        // Create a map of topic IDs to trend scores for quick lookup
        let topicScoreMap: [String: Double] = Dictionary(
            uniqueKeysWithValues: trendingTopics.map { ($0.id, $0.trendScore) }
        )
        
        // Normalize posts for scoring
        let normalizedPosts = normalizePosts(posts, topicScoreMap: topicScoreMap)
        
        // Sort by combined score (personalized topic relevance + recency + popularity)
        let sortedPostsWithScores = normalizedPosts.sorted { post1, post2 in
            let score1 = calculateCombinedScore(post1)
            let score2 = calculateCombinedScore(post2)
            
            if abs(score1 - score2) < 0.0001 {
                return post1.post.createdAt > post2.post.createdAt
            }
            
            return score1 > score2
        }
        
        // Extract posts from PostWithScores
        return sortedPostsWithScores.map { $0.post }
    }
    
    /// Calculate combined score from personalized topic relevance, recency, and popularity
    private func calculateCombinedScore(_ post: PostWithScores) -> Double {
        let topicScore = post.normalizedTopicRelevance * topicWeight
        let recencyScore = post.normalizedRecency * recencyWeight
        let popularityScore = post.normalizedPopularity * popularityWeight
        return topicScore + recencyScore + popularityScore
    }
    
    /// Normalize posts for scoring
    private func normalizePosts(_ posts: [Post], topicScoreMap: [String: Double]) -> [PostWithScores] {
        guard !posts.isEmpty else { return [] }
        
        // Find min/max values for normalization
        let now = Date().timeIntervalSince1970
        let times = posts.map { now - $0.createdAt.timeIntervalSince1970 }
        let maxTime = times.max() ?? 1
        let minTime = times.min() ?? 0
        
        let engagementScores = posts.map { calculateEngagementScore($0) }
        let maxEngagement = engagementScores.max() ?? 1
        let minEngagement = engagementScores.min() ?? 0
        
        let topicScores = posts.map { calculatePersonalizedTopicRelevance($0, topicScoreMap: topicScoreMap) }
        let maxTopic = topicScores.max() ?? 1
        let minTopic = topicScores.min() ?? 0
        
        // Normalize scores (0 to 1)
        return zip(posts, zip(zip(times, engagementScores), topicScores)).map { post, scores in
            let ((time, engagement), topic) = scores
            
            // Recency: newer posts get higher score (inverse of time since creation)
            let recencyNormalized = maxTime > minTime ? 1.0 - (time - minTime) / (maxTime - minTime) : 1.0
            
            // Popularity: higher engagement gets higher score
            let popularityNormalized = maxEngagement > minEngagement ? Double(engagement - minEngagement) / Double(maxEngagement - minEngagement) : 0.0
            
            // Topic relevance: posts matching trending topics and user preferences get higher score
            let topicNormalized = maxTopic > minTopic ? Double(topic - minTopic) / Double(maxTopic - minTopic) : 0.0
            
            return PostWithScores(
                post: post,
                normalizedRecency: recencyNormalized,
                normalizedPopularity: popularityNormalized,
                normalizedTopicRelevance: topicNormalized
            )
        }
    }
    
    /// Calculate personalized topic relevance score for a post
    /// Combines trending topic scores with user preference weights
    private func calculatePersonalizedTopicRelevance(_ post: Post, topicScoreMap: [String: Double]) -> Double {
        var totalScore: Double = 0.0
        
        // Check tags
        if let tags = post.tags {
            for tag in tags {
                let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
                var score: Double = 0.0
                
                // Base score from trending topics
                if let topicScore = topicScoreMap[normalized] {
                    score = topicScore
                }
                
                // Boost if in user preferences
                if let prefs = userPreferences, prefs.preferredTags.contains(normalized) {
                    let preferenceWeight = prefs.tagWeights[normalized] ?? 1.0
                    score *= (1.0 + preferenceWeight * 0.5)
                }
                
                totalScore += score * 2.0
            }
        }
        
        // Check categories
        if let categories = post.categories {
            for category in categories {
                let normalized = category.lowercased().trimmingCharacters(in: .whitespaces)
                var score: Double = 0.0
                
                // Base score from trending topics
                if let topicScore = topicScoreMap[normalized] {
                    score = topicScore
                }
                
                // Boost if in user preferences
                if let prefs = userPreferences, prefs.preferredCategories.contains(normalized) {
                    let preferenceWeight = prefs.categoryWeights[normalized] ?? 1.0
                    score *= (1.0 + preferenceWeight * 0.5)
                }
                
                totalScore += score * 1.5
            }
        }
        
        return totalScore
    }
    
    /// Calculate engagement score for a post
    private func calculateEngagementScore(_ post: Post) -> Int {
        let likeWeight = 2
        let commentWeight = 3
        let viewWeight = 1
        let shareWeight = 2
        let saveWeight = 2
        
        let likes = post.likeCount * likeWeight
        let comments = post.commentCount * commentWeight
        let views = post.viewCount * viewWeight
        let shares = post.shareCount * shareWeight
        let saves = post.saveCount * saveWeight
        
        return likes + comments + views + shares + saves
    }
}

/// Helper struct to hold post with normalized scores including topic relevance
private struct PostWithScores {
    let post: Post
    let normalizedRecency: Double
    let normalizedPopularity: Double
    let normalizedTopicRelevance: Double
}
