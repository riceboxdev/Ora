//
//  RecencyStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Ranking strategy that sorts posts by creation date (newest first)
struct RecencyStrategy: RankingStrategy {
    var name: String {
        return "recency"
    }
    
    func rank(posts: [Post], for userId: String?) async -> [Post] {
        return posts.sorted { $0.createdAt > $1.createdAt }
    }
}

