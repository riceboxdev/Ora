//
//  FollowRecommendation.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Represents a follow recommendation from Stream's recommendation API
struct FollowRecommendation: Identifiable {
    let id: String // User ID extracted from feed ID
    let feedId: String // Full feed ID (e.g., "user:userId")
    let score: Double? // Recommendation score/confidence
    let reason: String? // Reason for recommendation
    
    /// Extract user ID from feed ID (e.g., "user:abc123" -> "abc123")
    init?(from recommendationData: [String: Any]) {
        guard let feedId = recommendationData["feed_id"] as? String ?? recommendationData["feedId"] as? String else {
            return nil
        }
        
        self.feedId = feedId
        
        // Extract user ID from feed ID (format: "user:userId" or just "userId")
        if feedId.contains(":") {
            let components = feedId.components(separatedBy: ":")
            if components.count >= 2 {
                self.id = components[1]
            } else {
                self.id = feedId
            }
        } else {
            self.id = feedId
        }
        
        // Extract optional fields
        if let scoreValue = recommendationData["score"] as? Double {
            self.score = scoreValue
        } else if let scoreValue = recommendationData["score"] as? Int {
            self.score = Double(scoreValue)
        } else {
            self.score = nil
        }
        
        self.reason = recommendationData["reason"] as? String
    }
}













