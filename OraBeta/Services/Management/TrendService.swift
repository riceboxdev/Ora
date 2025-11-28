//
//  TrendService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFunctions
import FirebaseAuth

@MainActor
class TrendService {
    private let functions = Functions.functions()
    
    static let shared = TrendService()
    
    private init() {}
    
    /// Get trending topics
    /// - Parameters:
    ///   - timeWindow: Time window for trends (24h, 7d, 30d)
    ///   - personalized: Whether to return personalized trends
    ///   - limit: Maximum number of topics to return
    /// - Returns: Array of trending topics
    func getTrendingTopics(
        timeWindow: TrendingTopic.TimeWindow = .hours24,
        personalized: Bool = false,
        limit: Int = 20
    ) async throws -> [TrendingTopic] {
        guard Auth.auth().currentUser != nil else {
            throw TrendError.notAuthenticated
        }
        
        let function = functions.httpsCallable("getTrendingTopics")
        
        let result = try await function.call([
            "timeWindow": timeWindow.rawValue,
            "personalized": personalized,
            "limit": limit
        ])
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success,
              let topicsData = response["topics"] as? [[String: Any]] else {
            throw TrendError.invalidResponse
        }
        
        return topicsData.compactMap { TrendingTopic(from: $0) }
    }
    
    /// Get personalized trends for home feed
    func getPersonalizedTrends(
        timeWindow: TrendingTopic.TimeWindow = .hours24,
        limit: Int = 10
    ) async throws -> [TrendingTopic] {
        return try await getTrendingTopics(
            timeWindow: timeWindow,
            personalized: true,
            limit: limit
        )
    }
    
    /// Get global trends for discover feed
    func getGlobalTrends(
        timeWindow: TrendingTopic.TimeWindow = .hours24,
        limit: Int = 20
    ) async throws -> [TrendingTopic] {
        return try await getTrendingTopics(
            timeWindow: timeWindow,
            personalized: false,
            limit: limit
        )
    }
    
    /// Get posts by topic
    /// - Parameters:
    ///   - topicId: Topic identifier
    ///   - topicType: Type of topic (label, tag, category)
    ///   - limit: Maximum number of posts to return
    ///   - timeWindow: Time window for posts
    /// - Returns: Array of post dictionaries
    func getPostsByTopic(
        topicId: String,
        topicType: TrendingTopic.TopicType,
        limit: Int = 20,
        timeWindow: TrendingTopic.TimeWindow = .days7
    ) async throws -> [[String: Any]] {
        guard Auth.auth().currentUser != nil else {
            throw TrendError.notAuthenticated
        }
        
        let function = functions.httpsCallable("getPostsByTopic")
        
        let result = try await function.call([
            "topicId": topicId,
            "topicType": topicType.rawValue,
            "limit": limit,
            "timeWindow": timeWindow.rawValue
        ])
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success,
              let posts = response["posts"] as? [[String: Any]] else {
            throw TrendError.invalidResponse
        }
        
        return posts
    }
}

enum TrendError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case networkError
    case missingIndex(String)
    case functionError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .missingIndex(let message):
            return "Configuration error: \(message)"
        case .functionError(let message):
            return "Function error: \(message)"
        }
    }
}
