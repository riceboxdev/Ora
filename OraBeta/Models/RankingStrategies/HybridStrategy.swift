//
//  HybridStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Ranking strategy that combines recency and popularity with configurable weights
struct HybridStrategy: RankingStrategy {
    var name: String {
        return "hybrid"
    }
    
    let recencyWeight: Double
    let popularityWeight: Double
    
    init(recencyWeight: Double = 0.3, popularityWeight: Double = 0.7) {
        self.recencyWeight = recencyWeight
        self.popularityWeight = popularityWeight
    }
    
    func rank(posts: [Post], for userId: String?) -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        // Normalize scores
        let normalizedPosts = normalizePosts(posts)
        
        // Sort by combined score
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
    
    /// Calculate combined score from recency and popularity
    private func calculateCombinedScore(_ post: PostWithScores) -> Double {
        let recencyScore = post.normalizedRecency * recencyWeight
        let popularityScore = post.normalizedPopularity * popularityWeight
        return recencyScore + popularityScore
    }
    
    /// Normalize posts for scoring
    private func normalizePosts(_ posts: [Post]) -> [PostWithScores] {
        guard !posts.isEmpty else { return [] }
        
        // Find min/max values for normalization
        let now = Date().timeIntervalSince1970
        let times = posts.map { now - $0.createdAt.timeIntervalSince1970 }
        let maxTime = times.max() ?? 1
        let minTime = times.min() ?? 0
        
        let engagementScores = posts.map { calculateEngagementScore($0) }
        let maxEngagement = engagementScores.max() ?? 1
        let minEngagement = engagementScores.min() ?? 0
        
        // Normalize scores (0 to 1)
        return zip(posts, zip(times, engagementScores)).map { post, scores in
            let (time, engagement) = scores
            
            // Recency: newer posts get higher score (inverse of time since creation)
            let recencyNormalized = maxTime > minTime ? 1.0 - (time - minTime) / (maxTime - minTime) : 1.0
            
            // Popularity: higher engagement gets higher score
            let popularityNormalized = maxEngagement > minEngagement ? Double(engagement - minEngagement) / Double(maxEngagement - minEngagement) : 0.0
            
            return PostWithScores(
                post: post,
                normalizedRecency: recencyNormalized,
                normalizedPopularity: popularityNormalized
            )
        }
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

/// Helper struct to hold post with normalized scores
/// Note: This is a separate struct from SemanticRelevanceStrategy's PostWithScores
/// to avoid conflicts, but they share the same basic structure
private struct PostWithScores {
    let post: Post
    let normalizedRecency: Double
    let normalizedPopularity: Double
}

