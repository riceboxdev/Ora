//
//  PreRankingStrategy.swift
//  OraBeta
//
//  Lightweight pre-ranking strategy for initial candidate filtering
//  Fast heuristic-based scoring for reducing candidate set
//

import Foundation

/// Lightweight pre-ranking strategy for filtering candidates in multi-stage pipeline
struct PreRankingStrategy: RankingStrategy {
    var name: String {
        return "pre_ranking"
    }
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        do {
            guard let userId = userId else {
                // Fallback: sort by recency if no user
                return posts.sorted { $0.createdAt > $1.createdAt }
            }
            
            let tasteGraph = try await TasteGraphService.shared.getUserTasteGraph(userId: userId)
            let topInterests = tasteGraph.topInterests(count: 10)
            let userInterestIds = Set(topInterests.map { $0.interestId })
            let interestAffinityMap = Dictionary(uniqueKeysWithValues: topInterests.map { ($0.interestId, $0.currentScore()) })
            
            var scoredPosts: [(post: Post, score: Double)] = []
            
            for post in posts {
                let score = calculateScore(
                    post: post,
                    userInterestIds: userInterestIds,
                    interestAffinityMap: interestAffinityMap
                )
                scoredPosts.append((post, score))
            }
            
            return scoredPosts
                .sorted { $0.score > $1.score }
                .map { $0.post }
            
        } catch {
            return posts.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Scoring Logic
    
    private func calculateScore(
        post: Post,
        userInterestIds: Set<String>,
        interestAffinityMap: [String: Double]
    ) -> Double {
        var score = 0.0
        
        // 1. Interest Match (50%) - primary factor for pre-ranking
        if let postInterestIds = post.interestIds {
            let matchedInterests = postInterestIds.filter { userInterestIds.contains($0) }
            if !matchedInterests.isEmpty {
                let maxAffinity = matchedInterests
                    .compactMap { interestAffinityMap[$0] }
                    .max() ?? 0.0
                score += maxAffinity * 0.5
            }
        }
        
        // 2. Engagement Signal (30%) - basic quality signal
        let totalEngagement = Double(post.likeCount + post.commentCount + post.saveCount)
        let views = Double(max(post.viewCount, 1))
        let engagementRate = min(totalEngagement / views * 10.0, 1.0)
        score += engagementRate * 0.3
        
        // 3. Freshness (20%) - recent content preferred
        let ageInHours = Date().timeIntervalSince(post.createdAt) / 3600.0
        let freshnessScore = exp(-0.05 * ageInHours)
        score += freshnessScore * 0.2
        
        return score
    }
}
