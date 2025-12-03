//
//  TasteBasedRankingStrategy.swift
//  OraBeta
//
//  Ranking strategy based on Pinterest's Taste Graph architecture
//  Unified scoring algorithm combining interest relevance, content quality, creator quality, and freshness
//

import Foundation

/// Ranking strategy that prioritizes posts based on user's taste graph and interest affinities
/// Implements Pinterest's multi-factor scoring: Interest (40%) + Content (30%) + Creator (15%) + Freshness (15%)
struct TasteBasedRankingStrategy: RankingStrategy {
    var name: String {
        return "taste_based"
    }
    
    // Weights for ranking components (Pinterest-inspired)
    private let interestWeight = 0.40
    private let contentQualityWeight = 0.30
    private let creatorQualityWeight = 0.15
    private let freshnessWeight = 0.15
    
    // Configuration for quality scoring
    private let engagementCap = 1000
    private let maxEngagementRate = 0.1
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        guard let userId = userId, !posts.isEmpty else {
            return posts.sorted { $0.createdAt > $1.createdAt }
        }
        
        do {
            let tasteGraph = try await TasteGraphService.shared.getUserTasteGraph(userId: userId)
            let topInterests = tasteGraph.topInterests(count: 20)
            let userInterestIds = Set(topInterests.map { $0.interestId })
            
            let interestAffinityMap = Dictionary(uniqueKeysWithValues: topInterests.map { ($0.interestId, $0.currentScore()) })
            
            var scoredPosts: [(post: Post, score: Double)] = []
            
            for post in posts {
                let score = await calculatePostScore(
                    post: post,
                    userInterestIds: userInterestIds,
                    interestAffinityMap: interestAffinityMap
                )
                scoredPosts.append((post, score))
            }
            
            let ranked = scoredPosts
                .sorted { $0.score > $1.score }
                .map { $0.post }
            
            return applyDiversityReranking(ranked)
            
        } catch {
            return posts.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Scoring Logic
    
    /// Calculate unified post score combining all factors
    private func calculatePostScore(
        post: Post,
        userInterestIds: Set<String>,
        interestAffinityMap: [String: Double]
    ) async -> Double {
        // 1. Interest Relevance (40%)
        let interestRelevance = calculateInterestRelevance(
            post: post,
            interestAffinityMap: interestAffinityMap
        )
        
        // 2. Content Quality (30%)
        let contentQuality = calculateContentQuality(post: post)
        
        // 3. Creator Quality (15%)
        let creatorQuality = calculateCreatorQuality(post: post)
        
        // 4. Freshness (15%)
        let freshness = calculateFreshness(post: post)
        
        let totalScore = (interestRelevance * interestWeight) +
                        (contentQuality * contentQualityWeight) +
                        (creatorQuality * creatorQualityWeight) +
                        (freshness * freshnessWeight)
        
        return totalScore
    }
    
    /// Calculate how relevant post is to user's interests
    private func calculateInterestRelevance(
        post: Post,
        interestAffinityMap: [String: Double]
    ) -> Double {
        var maxRelevance = 0.0
        var totalRelevance = 0.0
        var count = 0
        
        if let interestIds = post.interestIds, !interestIds.isEmpty {
            for interestId in interestIds {
                if let affinityScore = interestAffinityMap[interestId] {
                    let confidence = post.interestScores?[interestId] ?? 1.0
                    let relevance = affinityScore * confidence
                    
                    maxRelevance = max(maxRelevance, relevance)
                    totalRelevance += relevance
                    count += 1
                }
            }
        }
        
        if count > 0 {
            let averageRelevance = totalRelevance / Double(count)
            return max(maxRelevance, averageRelevance * 0.8)
        }
        
        return maxRelevance
    }
    
    /// Calculate content quality based on engagement metrics
    private func calculateContentQuality(post: Post) -> Double {
        let likes = Double(post.likeCount)
        let comments = Double(post.commentCount)
        let saves = Double(post.saveCount)
        let shares = Double(post.shareCount)
        let views = Double(max(post.viewCount, 1))
        
        // Weighted engagement: saves and shares indicate stronger interest
        let weightedEngagement = (likes * 1.0) +
                                (comments * 2.0) +
                                (saves * 3.0) +
                                (shares * 3.0)
        
        // Engagement rate
        let engagementRate = min(weightedEngagement / views, maxEngagementRate)
        
        // Normalize to 0-1 range
        return engagementRate / maxEngagementRate
    }
    
    /// Calculate creator quality based on available metrics
    private func calculateCreatorQuality(post: Post) -> Double {
        var score = 0.5
        
        if let userProfilePhotoUrl = post.userProfilePhotoUrl, !userProfilePhotoUrl.isEmpty {
            score += 0.1
        }
        
        if let username = post.username, !username.isEmpty && username.count > 2 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    /// Calculate freshness score using exponential decay
    private func calculateFreshness(post: Post) -> Double {
        let now = Date()
        let ageInHours = now.timeIntervalSince(post.createdAt) / 3600.0
        
        return exp(-0.03 * ageInHours)
    }
    
    // MARK: - Diversity Re-ranking
    
    private func applyDiversityReranking(_ posts: [Post]) -> [Post] {
        // Pinterest re-ranking: avoid showing too many posts from same interest consecutively
        var result: [Post] = []
        var recentInterests: [String] = []
        let windowSize = 3 // Don't show same primary interest within 3 posts
        
        // Queue of skipped posts to re-insert later
        var skippedPosts: [Post] = []
        
        for post in posts {
            if let primaryInterest = post.primaryInterestId {
                if !recentInterests.contains(primaryInterest) {
                    result.append(post)
                    
                    // Update window
                    recentInterests.append(primaryInterest)
                    if recentInterests.count > windowSize {
                        recentInterests.removeFirst()
                    }
                } else {
                    // Skip and try to insert later
                    skippedPosts.append(post)
                }
            } else {
                // No interest, just append
                result.append(post)
            }
        }
        
        // Append skipped posts at the end
        result.append(contentsOf: skippedPosts)
        
        return result
    }
}
