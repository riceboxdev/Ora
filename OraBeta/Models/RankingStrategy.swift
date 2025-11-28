//
//  RankingStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Protocol for ranking strategies that determine how posts are ordered in feeds
protocol RankingStrategy {
    /// Rank posts according to the strategy
    /// - Parameters:
    ///   - posts: Array of posts to rank
    ///   - userId: Optional user ID for personalized ranking
    /// - Returns: Ranked array of posts
    func rank(posts: [Post], for userId: String?) -> [Post]
    
    /// Name of the ranking strategy
    var name: String { get }
}

/// Configuration for ranking strategies
struct RankingConfig {
    let strategyName: String
    let weights: [String: Double]?
    
    init(strategyName: String, weights: [String: Double]? = nil) {
        self.strategyName = strategyName
        self.weights = weights
    }
}

/// Default ranking strategies
enum DefaultRankingStrategy: String, CaseIterable {
    case recency = "recency"
    case popularity = "popularity"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .recency:
            return "Recent"
        case .popularity:
            return "Popular"
        case .hybrid:
            return "Trending"
        }
    }
}

