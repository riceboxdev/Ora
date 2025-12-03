//
//  DiversityRankingStrategy.swift
//  OraBeta
//
//  Diversity-focused re-ranking strategy
//  Avoids showing too many posts from the same interest consecutively
//

import Foundation

/// Re-ranking strategy that optimizes for diversity across interests
struct DiversityRankingStrategy: RankingStrategy {
    var name: String {
        return "diversity_reranking"
    }
    
    private let windowSize: Int
    private let diversityBoost: Double
    
    init(windowSize: Int = 3, diversityBoost: Double = 0.2) {
        self.windowSize = windowSize
        self.diversityBoost = diversityBoost
    }
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        return applyDiversityReranking(posts)
    }
    
    // MARK: - Diversity Re-ranking Algorithm
    
    /// Apply diversity optimization to avoid interest repetition
    /// Uses a sliding window approach with backfilling of skipped posts
    private func applyDiversityReranking(_ posts: [Post]) -> [Post] {
        var result: [Post] = []
        var recentInterests: [String] = []
        var skippedPosts: [(post: Post, reason: SkipReason)] = []
        
        // First pass: select diverse posts
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
                    skippedPosts.append((post, .interestRepetition(primaryInterest)))
                }
            } else {
                // No classification - include as diversity filler
                result.append(post)
            }
        }
        
        // Second pass: intelligently backfill skipped posts
        result.append(contentsOf: intelligentBackfill(skippedPosts, existingInterests: recentInterests))
        
        return result
    }
    
    /// Intelligently backfill skipped posts to improve diversity
    private func intelligentBackfill(
        _ skippedPosts: [(post: Post, reason: SkipReason)],
        existingInterests: [String]
    ) -> [Post] {
        var backfilled: [Post] = []
        var usedInterests = Set(existingInterests)
        
        for (post, _) in skippedPosts {
            if let primaryInterest = post.primaryInterestId {
                // Prefer posts with interests we haven't used yet
                if !usedInterests.contains(primaryInterest) {
                    backfilled.append(post)
                    usedInterests.insert(primaryInterest)
                }
            } else {
                // Include posts without classification
                backfilled.append(post)
            }
        }
        
        // Add remaining posts (those with repeated interests)
        for (post, _) in skippedPosts {
            if !backfilled.contains(where: { $0.id == post.id }) {
                backfilled.append(post)
            }
        }
        
        return backfilled
    }
    
    enum SkipReason {
        case interestRepetition(String)
        case creatorRepetition(String)
        case topicOverload(String)
    }
}

/// Hybrid re-ranking strategy combining score-based ranking with diversity
struct HybridDiversityStrategy: RankingStrategy {
    var name: String {
        return "hybrid_diversity"
    }
    
    private let diversityWeight: Double
    private let scoreWeight: Double
    private let windowSize: Int
    
    init(diversityWeight: Double = 0.3, scoreWeight: Double = 0.7, windowSize: Int = 5) {
        self.diversityWeight = diversityWeight
        self.scoreWeight = scoreWeight
        self.windowSize = windowSize
    }
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        guard !posts.isEmpty else { return posts }
        
        do {
            guard let userId = userId else {
                return applyDiversityConstraints(posts)
            }
            
            // Get taste graph for user
            let tasteGraph = try await TasteGraphService.shared.getUserTasteGraph(userId: userId)
            let topInterests = tasteGraph.topInterests(count: 10)
            let interestAffinityMap = Dictionary(uniqueKeysWithValues: topInterests.map { ($0.interestId, $0.currentScore()) })
            
            // Calculate hybrid scores
            var scoredPosts: [(post: Post, score: Double, diversity: Double)] = []
            
            for post in posts {
                let relevanceScore = calculateRelevance(post: post, affinityMap: interestAffinityMap)
                let diversityScore = calculateDiversityScore(post)
                let hybridScore = (relevanceScore * scoreWeight) + (diversityScore * diversityWeight)
                
                scoredPosts.append((post, hybridScore, diversityScore))
            }
            
            // Sort by hybrid score
            let ranked = scoredPosts
                .sorted { $0.score > $1.score }
                .map { $0.post }
            
            // Apply diversity constraints
            return applyDiversityConstraints(ranked)
            
        } catch {
            return applyDiversityConstraints(posts)
        }
    }
    
    private func calculateRelevance(
        post: Post,
        affinityMap: [String: Double]
    ) -> Double {
        guard let interestIds = post.interestIds else { return 0.0 }
        
        return interestIds
            .compactMap { affinityMap[$0] }
            .max() ?? 0.0
    }
    
    private func calculateDiversityScore(_ post: Post) -> Double {
        // Posts without primary interest get higher diversity bonus
        // (they serve as fillers between repeated interests)
        return post.primaryInterestId == nil ? 0.8 : 0.5
    }
    
    private func applyDiversityConstraints(_ posts: [Post]) -> [Post] {
        var result: [Post] = []
        var recentInterests: [String] = []
        
        for post in posts {
            if let primaryInterest = post.primaryInterestId {
                if !recentInterests.contains(primaryInterest) {
                    result.append(post)
                    recentInterests.append(primaryInterest)
                    if recentInterests.count > windowSize {
                        recentInterests.removeFirst()
                    }
                }
            } else {
                result.append(post)
            }
        }
        
        return result
    }
}
