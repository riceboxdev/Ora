//
//  PostInterestClassification.swift
//  OraBeta
//
//  Model for storing Pin2Interest classification results
//  Based on Pinterest's P2I classification system
//

import Foundation
import FirebaseFirestore

/// Classification result for a post mapped to interests
struct PostInterestClassification: Codable, Equatable {
    let postId: String
    let classifications: [Classification]
    let classifiedAt: Date
    let version: String                 // Classification model version (e.g., "1.0")
    
    struct Classification: Codable, Equatable, Identifiable {
        var id: String { interestId }
        
        let interestId: String
        let interestName: String
        let interestLevel: Int          // Depth in taxonomy
        let confidence: Double          // 0.0 to 1.0
        let signals: [ClassificationSignal]
        
        enum ClassificationSignal: String, Codable, Equatable {
            case userTagged             // User explicitly selected this interest
            case captionMatch           // Found in caption text
            case userProvidedTag        // Found in user's tags
            case boardName              // Matched board name where saved
            case similarPosts           // Posts with similar content have this interest
            case userBehavior           // Users who engage have this interest
            case visualSimilarity       // Image analysis matched (future)
            case tfIdf                  // TF-IDF score high (future)
        }
    }
    
    init(
        postId: String,
        classifications: [Classification],
        classifiedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.postId = postId
        self.classifications = classifications
        self.classifiedAt = classifiedAt
        self.version = version
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case postId, classifications, classifiedAt, version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        postId = try container.decode(String.self, forKey: .postId)
        classifications = try container.decode([Classification].self, forKey: .classifications)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        
        // Handle Timestamp from Firestore
        if let timestamp = try? container.decode(Timestamp.self, forKey: .classifiedAt) {
            classifiedAt = timestamp.dateValue()
        } else {
            classifiedAt = try container.decodeIfPresent(Date.self, forKey: .classifiedAt) ?? Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(postId, forKey: .postId)
        try container.encode(classifications, forKey: .classifications)
        try container.encode(classifiedAt, forKey: .classifiedAt)
        try container.encode(version, forKey: .version)
    }
    
    // MARK: - Computed Properties
    
    /// Get classifications above a confidence threshold
    /// - Parameter threshold: Minimum confidence (default: 0.7)
    /// - Returns: High-confidence classifications
    func highConfidenceInterests(threshold: Double = 0.7) -> [Classification] {
        return classifications.filter { $0.confidence >= threshold }
    }
    
    /// Get the primary (highest confidence) interest
    var primaryInterest: Classification? {
        return classifications.max(by: { $0.confidence < $1.confidence })
    }
    
    /// Get interest IDs sorted by confidence
    var interestIdsByConfidence: [String] {
        return classifications
            .sorted { $0.confidence > $1.confidence }
            .map { $0.interestId }
    }
    
    /// Get classifications for a specific level
    /// - Parameter level: Taxonomy level
    /// - Returns: Classifications at that level
    func classificationsAtLevel(_ level: Int) -> [Classification] {
        return classifications.filter { $0.interestLevel == level }
    }
    
    // MARK: - Factory Methods
    
    /// Create from Firestore document
    static func from(document: DocumentSnapshot) throws -> PostInterestClassification? {
        guard let data = document.data() else { return nil }
        return try from(dictionary: data, postId: document.documentID)
    }
    
    /// Create from dictionary
    static func from(dictionary: [String: Any], postId: String) throws -> PostInterestClassification {
        let classificationsData = dictionary["classifications"] as? [[String: Any]] ?? []
        var classifications: [Classification] = []
        
        for classData in classificationsData {
            let interestId = classData["interestId"] as? String ?? ""
            let interestName = classData["interestName"] as? String ?? ""
            let interestLevel = classData["interestLevel"] as? Int ?? 0
            let confidence = classData["confidence"] as? Double ?? 0.0
            let signalsRaw = classData["signals"] as? [String] ?? []
            let signals = signalsRaw.compactMap { Classification.ClassificationSignal(rawValue: $0) }
            
            classifications.append(Classification(
                interestId: interestId,
                interestName: interestName,
                interestLevel: interestLevel,
                confidence: confidence,
                signals: signals
            ))
        }
        
        let version = dictionary["version"] as? String ?? "1.0"
        
        var classifiedAt = Date()
        if let timestamp = dictionary["classifiedAt"] as? Timestamp {
            classifiedAt = timestamp.dateValue()
        } else if let date = dictionary["classifiedAt"] as? Date {
            classifiedAt = date
        }
        
        return PostInterestClassification(
            postId: postId,
            classifications: classifications,
            classifiedAt: classifiedAt,
            version: version
        )
    }
    
    /// Convert to Firestore dictionary
    func toFirestoreData() -> [String: Any] {
        let classificationsData = classifications.map { classification in
            [
                "interestId": classification.interestId,
                "interestName": classification.interestName,
                "interestLevel": classification.interestLevel,
                "confidence": classification.confidence,
                "signals": classification.signals.map { $0.rawValue }
            ] as [String: Any]
        }
        
        return [
            "postId": postId,
            "classifications": classificationsData,
            "classifiedAt": Timestamp(date: classifiedAt),
            "version": version
        ]
    }
}

// MARK: - Interest Candidate (for Stage 1)

struct InterestCandidate: Equatable {
    let interestId: String
    let interestName: String
    let interestLevel: Int
    let matchScore: Double              // Initial match score from candidate generation
    let signals: [PostInterestClassification.Classification.ClassificationSignal]
    
    /// Convert to Classification with final confidence
    func toClassification(confidence: Double) -> PostInterestClassification.Classification {
        return PostInterestClassification.Classification(
            interestId: interestId,
            interestName: interestName,
            interestLevel: interestLevel,
            confidence: confidence,
            signals: signals
        )
    }
}
