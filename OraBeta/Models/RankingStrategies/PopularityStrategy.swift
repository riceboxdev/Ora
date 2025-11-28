//
//  PopularityStrategy.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Ranking strategy that sorts posts by engagement score (likes + comments + views)
struct PopularityStrategy: RankingStrategy {
    var name: String {
        return "popularity"
    }
    
    func rank(posts: [Post], for userId: String?) -> [Post] {
        return posts.sorted { post1, post2 in
            let score1 = calculateEngagementScore(post1)
            let score2 = calculateEngagementScore(post2)
            
            // If scores are equal, sort by recency
            if score1 == score2 {
                return post1.createdAt > post2.createdAt
            }
            
            return score1 > score2
        }
    }
    
    /// Calculate engagement score for a post
    /// Weight: likes = 2, comments = 3, views = 1, shares = 2, saves = 2
    /// Bonus: +5 for posts with semantic labels (indicates richer content)
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

