//
//  FeedRankingPipeline.swift
//  OraBeta
//
//  Multi-stage feed ranking pipeline
//  Implements Pinterest's 4-stage ranking: Candidate Retrieval → Pre-Ranking → Ranking → Re-Ranking
//

import Foundation

@MainActor
class FeedRankingPipeline {
    private let tasteGraphService = TasteGraphService.shared
    private let interestService = InterestTaxonomyService.shared
    
    static let shared = FeedRankingPipeline()
    
    private init() {}
    
    // MARK: - Pipeline Configuration
    
    struct PipelineConfig {
        let candidateLimit: Int = 500
        let preRankingLimit: Int = 100
        let finalLimit: Int = 50
        let diversityWindowSize: Int = 3
    }
    
    private let config = PipelineConfig()
    
    // MARK: - Main Pipeline Entry Point
    
    /// Execute the full multi-stage ranking pipeline
    /// - Parameters:
    ///   - posts: Initial post candidates
    ///   - userId: User ID for personalization
    ///   - strategy: Main ranking strategy to use
    /// - Returns: Ranked and re-ranked posts
    func rankFeed(
        posts: [Post],
        userId: String,
        strategy: RankingStrategy? = nil
    ) async -> [Post] {
        do {
            // Stage 1: Candidate Retrieval (already done - posts passed in)
            var candidates = posts
            
            // Stage 2: Pre-Ranking (lightweight filtering)
            candidates = try await preRank(candidates, userId: userId)
            
            // Stage 3: Main Ranking
            let rankingStrategy = strategy ?? TasteBasedRankingStrategy()
            candidates = await rankingStrategy.rank(posts: candidates, for: userId)
            
            // Stage 4: Diversity Re-Ranking
            candidates = await applyDiversityReranking(candidates, userId: userId)
            
            return candidates
        } catch {
            return posts.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Stage 2: Pre-Ranking
    
    /// Fast pre-ranking stage to filter candidates
    /// Uses lightweight heuristics for quick scoring
    private func preRank(_ posts: [Post], userId: String) async throws -> [Post] {
        do {
            let tasteGraph = try await tasteGraphService.getUserTasteGraph(userId: userId)
            let topInterestIds = Set(tasteGraph.topInterests(count: 10).map { $0.interestId })
            
            var scoredPosts: [(post: Post, score: Double)] = []
            
            for post in posts {
                let score = calculatePreRankScore(
                    post: post,
                    userInterestIds: topInterestIds
                )
                scoredPosts.append((post, score))
            }
            
            let preRanked = scoredPosts
                .sorted { $0.score > $1.score }
                .prefix(config.preRankingLimit)
                .map { $0.post }
            
            return Array(preRanked)
        } catch {
            return Array(posts.prefix(config.preRankingLimit))
        }
    }
    
    /// Calculate pre-ranking score (simplified, fast)
    /// Focuses on quick signals: interest match + basic freshness
    private func calculatePreRankScore(
        post: Post,
        userInterestIds: Set<String>
    ) -> Double {
        var score = 0.0
        
        // Interest match bonus (60%)
        if let postInterestIds = post.interestIds {
            let matchCount = postInterestIds.filter { userInterestIds.contains($0) }.count
            let matchRatio = Double(matchCount) / Double(max(postInterestIds.count, 1))
            score += matchRatio * 0.6
        }
        
        // Engagement signal (30%)
        let totalEngagement = Double(post.likeCount + post.commentCount + post.saveCount)
        let engagementScore = min(totalEngagement / 100.0, 1.0)
        score += engagementScore * 0.3
        
        // Freshness (10%)
        let ageInDays = Date().timeIntervalSince(post.createdAt) / 86400.0
        let freshnessScore = exp(-0.1 * ageInDays)
        score += freshnessScore * 0.1
        
        return score
    }
    
    // MARK: - Stage 4: Diversity Re-Ranking
    
    /// Apply diversity re-ranking to reduce repetition of same interests
    private func applyDiversityReranking(_ posts: [Post], userId: String) async -> [Post] {
        var result: [Post] = []
        var recentInterests: [String] = []
        var skippedPosts: [Post] = []
        
        for post in posts {
            if let primaryInterest = post.primaryInterestId {
                // Check if this interest was recently shown
                if !recentInterests.contains(primaryInterest) {
                    result.append(post)
                    
                    // Update recent interests window
                    recentInterests.append(primaryInterest)
                    if recentInterests.count > config.diversityWindowSize {
                        recentInterests.removeFirst()
                    }
                } else {
                    // Skip and add to queue for later insertion
                    skippedPosts.append(post)
                }
            } else {
                // No primary interest classification, include it
                result.append(post)
            }
        }
        
        // Append skipped posts at the end
        result.append(contentsOf: skippedPosts)
        
        return result
    }
    
    // MARK: - Candidate Retrieval Helper
    
    /// Retrieve initial candidates based on user's taste graph
    /// Can be used to pre-filter posts from Firestore query
    func getRelevantInterestIds(for userId: String, limit: Int = 20) async throws -> [String] {
        let tasteGraph = try await tasteGraphService.getUserTasteGraph(userId: userId)
        return tasteGraph.topInterests(count: limit).map { $0.interestId }
    }
}
