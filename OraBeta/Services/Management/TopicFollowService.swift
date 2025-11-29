//
//  TopicFollowService.swift
//  OraBeta
//
//  Service for managing topic follow relationships
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TopicFollowService {
    private let db = Firestore.firestore()
    private let topicFollowsCollection = "topic_follows"
    
    static let shared = TopicFollowService()
    
    private init() {}
    
    /// Follow a topic
    /// - Parameters:
    ///   - topicName: Name of the topic to follow
    ///   - topicType: Type of topic (label, tag, category)
    func followTopic(topicName: String, topicType: TrendingTopic.TopicType) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw TopicFollowError.notAuthenticated
        }
        
        // Create follow relationship in Firestore
        // Document ID format: "{userId}_{topicType}_{topicName}"
        let followId = "\(userId)_\(topicType.rawValue)_\(topicName.lowercased())"
        
        // Check if already following
        let followDoc = try await db.collection(topicFollowsCollection).document(followId).getDocument()
        
        if followDoc.exists {
            Logger.info("Already following topic \(topicName) (\(topicType.rawValue))", service: "TopicFollowService")
            return
        }
        
        // Create follow relationship
        try await db.collection(topicFollowsCollection).document(followId).setData([
            "userId": userId,
            "topicName": topicName,
            "topicType": topicType.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        Logger.info("Successfully followed topic \(topicName) (\(topicType.rawValue))", service: "TopicFollowService")
    }
    
    /// Unfollow a topic
    /// - Parameters:
    ///   - topicName: Name of the topic to unfollow
    ///   - topicType: Type of topic (label, tag, category)
    func unfollowTopic(topicName: String, topicType: TrendingTopic.TopicType) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw TopicFollowError.notAuthenticated
        }
        
        let followId = "\(userId)_\(topicType.rawValue)_\(topicName.lowercased())"
        let followDoc = try await db.collection(topicFollowsCollection).document(followId).getDocument()
        
        guard followDoc.exists else {
            Logger.info("Not following topic \(topicName) (\(topicType.rawValue))", service: "TopicFollowService")
            return
        }
        
        // Delete follow relationship
        try await db.collection(topicFollowsCollection).document(followId).delete()
        
        Logger.info("Successfully unfollowed topic \(topicName) (\(topicType.rawValue))", service: "TopicFollowService")
    }
    
    /// Check if current user is following a topic
    /// - Parameters:
    ///   - topicName: Name of the topic
    ///   - topicType: Type of topic (label, tag, category)
    /// - Returns: True if following, false otherwise
    func isFollowingTopic(topicName: String, topicType: TrendingTopic.TopicType) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let followId = "\(userId)_\(topicType.rawValue)_\(topicName.lowercased())"
        let followDoc = try await db.collection(topicFollowsCollection).document(followId).getDocument()
        return followDoc.exists
    }
    
    /// Get all topics the current user is following
    /// - Returns: Array of (topicName, topicType) tuples
    func getFollowedTopics() async throws -> [(name: String, type: TrendingTopic.TopicType)] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw TopicFollowError.notAuthenticated
        }
        
        let snapshot = try await db.collection(topicFollowsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var followedTopics: [(name: String, type: TrendingTopic.TopicType)] = []
        
        for document in snapshot.documents {
            let data = document.data()
            if let topicName = data["topicName"] as? String,
               let topicTypeString = data["topicType"] as? String,
               let topicType = TrendingTopic.TopicType(rawValue: topicTypeString) {
                followedTopics.append((name: topicName, type: topicType))
            }
        }
        
        Logger.info("Found \(followedTopics.count) followed topics", service: "TopicFollowService")
        return followedTopics
    }
    
    /// Batch check which topics from a list are being followed
    /// - Parameter topics: Array of topics to check
    /// - Returns: Set of topic IDs (format: "{topicType}_{topicName}") that are being followed
    func getFollowedTopicIds(from topics: [TrendingTopic]) async throws -> Set<String> {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        // Build topic IDs to check
        let topicIds = topics.map { "\($0.type.rawValue)_\($0.name.lowercased())" }
        
        // Query all follows for this user
        let snapshot = try await db.collection(topicFollowsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var followedIds: Set<String> = []
        
        for document in snapshot.documents {
            let data = document.data()
            if let topicName = data["topicName"] as? String,
               let topicTypeString = data["topicType"] as? String {
                let topicId = "\(topicTypeString)_\(topicName.lowercased())"
                if topicIds.contains(topicId) {
                    followedIds.insert(topicId)
                }
            }
        }
        
        return followedIds
    }
}

enum TopicFollowError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        }
    }
}













