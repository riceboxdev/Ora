//
//  TopicRankingStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Ranking strategy that prioritizes posts based on trending topics (global trends)
struct TopicRankingStrategy: RankingStrategy {
    var name: String {
        return "topic_ranking"
    }
    
    let trendingTopics: [TrendingTopic] // Global trending topics
    let topicWeight: Double // Weight for topic relevance
    let recencyWeight: Double // Weight for recency
    let popularityWeight: Double // Weight for popularity
    
    init(
        trendingTopics: [TrendingTopic] = [],
        topicWeight: Double = 0.4,
        recencyWeight: Double = 0.3,
        popularityWeight: Double = 0.3
    ) {
        self.trendingTopics = trendingTopics
        self.topicWeight = topicWeight
        self.recencyWeight = recencyWeight
        self.popularityWeight = popularityWeight
    }
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        // If no trending topics, fall back to hybrid strategy
        if trendingTopics.isEmpty {
            let hybridStrategy = HybridStrategy(recencyWeight: recencyWeight, popularityWeight: popularityWeight + topicWeight)
            return await hybridStrategy.rank(posts: posts, for: userId)
        }
        
        // Create a map of topic IDs to trend scores for quick lookup
        let topicScoreMap: [String: Double] = Dictionary(
            uniqueKeysWithValues: trendingTopics.map { ($0.id, $0.trendScore) }
        )
        
        // Normalize posts for scoring
        let normalizedPosts = normalizePosts(posts, topicScoreMap: topicScoreMap)
        
        // Sort by combined score (topic relevance + recency + popularity)
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
    
    /// Calculate combined score from topic relevance, recency, and popularity
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
        
        let topicScores = posts.map { calculateTopicRelevance($0, topicScoreMap: topicScoreMap) }
        let maxTopic = topicScores.max() ?? 1
        let minTopic = topicScores.min() ?? 0
        
        // Normalize scores (0 to 1)
        return zip(posts, zip(zip(times, engagementScores), topicScores)).map { post, scores in
            let ((time, engagement), topic) = scores
            
            // Recency: newer posts get higher score (inverse of time since creation)
            let recencyNormalized = maxTime > minTime ? 1.0 - (time - minTime) / (maxTime - minTime) : 1.0
            
            // Popularity: higher engagement gets higher score
            let popularityNormalized = maxEngagement > minEngagement ? Double(engagement - minEngagement) / Double(maxEngagement - minEngagement) : 0.0
            
            // Topic relevance: posts matching trending topics get higher score
            let topicNormalized = maxTopic > minTopic ? Double(topic - minTopic) / Double(maxTopic - minTopic) : 0.0
            
            return PostWithScores(
                post: post,
                normalizedRecency: recencyNormalized,
                normalizedPopularity: popularityNormalized,
                normalizedTopicRelevance: topicNormalized
            )
        }
    }
    
    /// Calculate topic relevance score for a post
    /// Checks if post's interests match trending topics
    private func calculateTopicRelevance(_ post: Post, topicScoreMap: [String: Double]) -> Double {
        var totalScore: Double = 0.0
        
        // Check interests
        if let interests = post.interestIds {
            for interestId in interests {
                let normalized = interestId.lowercased().trimmingCharacters(in: .whitespaces)
                if let score = topicScoreMap[normalized] {
                    totalScore += score * 2.0
                }
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
