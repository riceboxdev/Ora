//
//  UserTasteGraph.swift
//  OraBeta
//
//  Model for tracking user interest affinities (Taste Graph)
//  Based on Pinterest's Taste Graph architecture
//

import Foundation
import FirebaseFirestore

/// Represents a user's taste graph - their affinities for various interests
struct UserTasteGraph: Codable, Equatable {
    let userId: String
    let interests: [InterestAffinity]
    let lastUpdated: Date
    let version: Int                    // Schema version
    
    /// Represents a user's affinity for a specific interest
    struct InterestAffinity: Codable, Equatable, Identifiable {
        var id: String { interestId }
        
        let interestId: String
        let score: Double               // 0.0 to 1.0
        let source: AffinitySource
        let engagementCount: Int
        let firstEngagement: Date
        let lastEngagement: Date
        let decayFactor: Double         // Time-based decay factor
        
        enum AffinitySource: String, Codable, Equatable {
            case explicitFollow         // User clicked follow
            case inferredFromSaves      // User saves posts in this interest
            case inferredFromViews      // User views posts in this interest
            case inferredFromSearch     // User searches for this interest
            case inferredFromCreates    // User creates posts in this interest
        }
        
        // MARK: - Scoring Logic
        
        /// Calculate current score with time decay
        /// - Parameter now: Current date (default: Date())
        /// - Returns: Decayed score (0.0 to 1.0)
        func currentScore(now: Date = Date()) -> Double {
            // Calculate days since last engagement
            let daysSinceLastEngagement = max(0, now.timeIntervalSince(lastEngagement) / 86400)
            
            // Apply exponential decay
            // Formula: score * e^(-decayFactor * days)
            // Default decay factor 0.01 means score drops to ~37% after 100 days if no engagement
            let decayed = score * exp(-decayFactor * daysSinceLastEngagement)
            
            return max(decayed, 0.0)
        }
    }
    
    // MARK: - Initialization
    
    init(
        userId: String,
        interests: [InterestAffinity] = [],
        lastUpdated: Date = Date(),
        version: Int = 1
    ) {
        self.userId = userId
        self.interests = interests
        self.lastUpdated = lastUpdated
        self.version = version
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case userId, interests, lastUpdated, version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decode(String.self, forKey: .userId)
        interests = try container.decode([InterestAffinity].self, forKey: .interests)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        
        // Handle Timestamp from Firestore
        if let timestamp = try? container.decode(Timestamp.self, forKey: .lastUpdated) {
            lastUpdated = timestamp.dateValue()
        } else {
            lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(userId, forKey: .userId)
        try container.encode(interests, forKey: .interests)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(version, forKey: .version)
    }
    
    // MARK: - Helper Methods
    
    /// Get top N interests by current score
    /// - Parameters:
    ///   - count: Number of interests to return
    ///   - now: Current date (for decay calculation)
    /// - Returns: Array of interest affinities sorted by score
    func topInterests(count: Int, now: Date = Date()) -> [InterestAffinity] {
        return interests
            .sorted { $0.currentScore(now: now) > $1.currentScore(now: now) }
            .prefix(count)
            .map { $0 }
    }
    
    /// Get affinity for a specific interest
    func affinity(for interestId: String) -> InterestAffinity? {
        return interests.first(where: { $0.interestId == interestId })
    }
    
    // MARK: - Factory Methods
    
    /// Create from Firestore document
    static func from(document: DocumentSnapshot) throws -> UserTasteGraph? {
        guard let data = document.data() else { return nil }
        return try from(dictionary: data, userId: document.documentID)
    }
    
    /// Create from dictionary
    static func from(dictionary: [String: Any], userId: String) throws -> UserTasteGraph {
        let interestsData = dictionary["interests"] as? [[String: Any]] ?? []
        var interests: [InterestAffinity] = []
        
        for item in interestsData {
            if let interestId = item["interestId"] as? String,
               let score = item["score"] as? Double,
               let sourceRaw = item["source"] as? String,
               let source = InterestAffinity.AffinitySource(rawValue: sourceRaw) {
                
                let engagementCount = item["engagementCount"] as? Int ?? 1
                let decayFactor = item["decayFactor"] as? Double ?? 0.01
                
                var firstEngagement = Date()
                if let ts = item["firstEngagement"] as? Timestamp {
                    firstEngagement = ts.dateValue()
                }
                
                var lastEngagement = Date()
                if let ts = item["lastEngagement"] as? Timestamp {
                    lastEngagement = ts.dateValue()
                }
                
                interests.append(InterestAffinity(
                    interestId: interestId,
                    score: score,
                    source: source,
                    engagementCount: engagementCount,
                    firstEngagement: firstEngagement,
                    lastEngagement: lastEngagement,
                    decayFactor: decayFactor
                ))
            }
        }
        
        var lastUpdated = Date()
        if let timestamp = dictionary["lastUpdated"] as? Timestamp {
            lastUpdated = timestamp.dateValue()
        }
        
        let version = dictionary["version"] as? Int ?? 1
        
        return UserTasteGraph(
            userId: userId,
            interests: interests,
            lastUpdated: lastUpdated,
            version: version
        )
    }
    
    /// Convert to Firestore dictionary
    func toFirestoreData() -> [String: Any] {
        let interestsData = interests.map { item in
            [
                "interestId": item.interestId,
                "score": item.score,
                "source": item.source.rawValue,
                "engagementCount": item.engagementCount,
                "firstEngagement": Timestamp(date: item.firstEngagement),
                "lastEngagement": Timestamp(date: item.lastEngagement),
                "decayFactor": item.decayFactor
            ] as [String: Any]
        }
        
        return [
            "userId": userId,
            "interests": interestsData,
            "lastUpdated": Timestamp(date: lastUpdated),
            "version": version
        ]
    }
}
