//
//  TrendingTopic.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

struct TrendingTopic: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let type: TopicType
    let name: String
    let postCount: Int
    let engagementScore: Double
    let userEngagementScore: Double
    let growthRate: Double
    let trendScore: Double
    let timeWindow: TimeWindow
    let topPosts: [String]
    let metadata: TopicMetadata?
    let personalized: Bool?
    
    enum TopicType: String, Codable, Equatable {
        case label
        case tag
        case category
    }
    
    enum TimeWindow: String, Codable, Equatable {
        case hours24 = "24h"
        case days7 = "7d"
        case days30 = "30d"
    }
    
    struct TopicMetadata: Codable, Equatable, Hashable {
        let uniqueEngagers: Int?
        let engagementVelocity: Double?
        let avgLikes: Double?
        let avgComments: Double?
        let avgViews: Double?
    }
    
    init(from dictionary: [String: Any]) {
        self.id = dictionary["id"] as? String ?? ""
        self.type = TopicType(rawValue: dictionary["type"] as? String ?? "tag") ?? .tag
        self.name = dictionary["name"] as? String ?? ""
        self.postCount = dictionary["postCount"] as? Int ?? 0
        self.engagementScore = dictionary["engagementScore"] as? Double ?? 0.0
        self.userEngagementScore = dictionary["userEngagementScore"] as? Double ?? 0.0
        self.growthRate = dictionary["growthRate"] as? Double ?? 0.0
        self.trendScore = dictionary["trendScore"] as? Double ?? 0.0
        self.timeWindow = TimeWindow(rawValue: dictionary["timeWindow"] as? String ?? "24h") ?? .hours24
        self.topPosts = dictionary["topPosts"] as? [String] ?? []
        self.personalized = dictionary["personalized"] as? Bool ?? false
        
        if let metadataDict = dictionary["metadata"] as? [String: Any] {
            self.metadata = TopicMetadata(
                uniqueEngagers: metadataDict["uniqueEngagers"] as? Int,
                engagementVelocity: metadataDict["engagementVelocity"] as? Double,
                avgLikes: metadataDict["avgLikes"] as? Double,
                avgComments: metadataDict["avgComments"] as? Double,
                avgViews: metadataDict["avgViews"] as? Double
            )
        } else {
            self.metadata = nil
        }
    }
}
