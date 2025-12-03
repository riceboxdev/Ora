//
//  PostInterestClassification.swift
//  OraBeta
//
//  Model for Pin2Interest classification results
//  Stores classified interests for a post with confidence scores
//

import Foundation
import FirebaseFirestore

struct PostInterestClassification: Identifiable, Codable, Equatable {
    var id: String { postId }
    
    let postId: String
    let classifications: [Classification]
    let classifiedAt: Date
    let version: String
    
    struct Classification: Codable, Equatable, Identifiable {
        var id: String { interestId }
        
        let interestId: String
        let interestName: String
        let interestLevel: Int
        let confidence: Double
        let signals: [ClassificationSignal]
        
        enum ClassificationSignal: String, Codable, Equatable {
            case userTagged
            case captionMatch
            case boardName
            case similarPosts
            case userBehavior
            case visualSimilarity
            case tfIdf
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case postId, classifications, classifiedAt, version
    }
    
    init(
        postId: String,
        classifications: [Classification] = [],
        classifiedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.postId = postId
        self.classifications = classifications
        self.classifiedAt = classifiedAt
        self.version = version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        postId = try container.decode(String.self, forKey: .postId)
        classifications = try container.decode([Classification].self, forKey: .classifications)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        
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
    
    func highConfidenceInterests(threshold: Double = 0.7) -> [Classification] {
        return classifications.filter { $0.confidence >= threshold }
    }
    
    func topInterests(limit: Int = 3) -> [Classification] {
        return Array(classifications
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit))
    }
    
    static func from(document: DocumentSnapshot) throws -> PostInterestClassification? {
        guard var data = document.data() else { return nil }
        data["postId"] = document.documentID
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(PostInterestClassification.self, from: jsonData)
    }
    
    func toFirestoreData() -> [String: Any] {
        let classificationsData = classifications.map { classification -> [String: Any] in
            return [
                "interestId": classification.interestId,
                "interestName": classification.interestName,
                "interestLevel": classification.interestLevel,
                "confidence": classification.confidence,
                "signals": classification.signals.map { $0.rawValue }
            ]
        }
        
        return [
            "postId": postId,
            "classifications": classificationsData,
            "classifiedAt": Timestamp(date: classifiedAt),
            "version": version
        ]
    }
}
