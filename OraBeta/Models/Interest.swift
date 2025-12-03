//
//  Interest.swift
//  OraBeta
//
//  Model for interest taxonomy nodes
//  Represents a single interest in the hierarchical taxonomy
//

import Foundation
import FirebaseFirestore

struct Interest: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let parentId: String?
    let level: Int
    let path: [String]
    let description: String?
    let coverImageUrl: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    let postCount: Int
    let followerCount: Int
    let weeklyGrowth: Double
    let monthlyGrowth: Double
    
    let relatedInterestIds: [String]
    let keywords: [String]
    let synonyms: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, parentId, level, path, description
        case coverImageUrl, isActive, createdAt, updatedAt
        case postCount, followerCount, weeklyGrowth, monthlyGrowth
        case relatedInterestIds, keywords, synonyms
    }
    
    init(
        id: String,
        name: String,
        displayName: String,
        parentId: String? = nil,
        level: Int = 0,
        path: [String] = [],
        description: String? = nil,
        coverImageUrl: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        postCount: Int = 0,
        followerCount: Int = 0,
        weeklyGrowth: Double = 0.0,
        monthlyGrowth: Double = 0.0,
        relatedInterestIds: [String] = [],
        keywords: [String] = [],
        synonyms: [String] = []
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.parentId = parentId
        self.level = level
        self.path = path
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.postCount = postCount
        self.followerCount = followerCount
        self.weeklyGrowth = weeklyGrowth
        self.monthlyGrowth = monthlyGrowth
        self.relatedInterestIds = relatedInterestIds
        self.keywords = keywords
        self.synonyms = synonyms
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        level = try container.decode(Int.self, forKey: .level)
        path = try container.decode([String].self, forKey: .path)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        postCount = try container.decodeIfPresent(Int.self, forKey: .postCount) ?? 0
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0
        weeklyGrowth = try container.decodeIfPresent(Double.self, forKey: .weeklyGrowth) ?? 0.0
        monthlyGrowth = try container.decodeIfPresent(Double.self, forKey: .monthlyGrowth) ?? 0.0
        
        relatedInterestIds = try container.decodeIfPresent([String].self, forKey: .relatedInterestIds) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(level, forKey: .level)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(postCount, forKey: .postCount)
        try container.encode(followerCount, forKey: .followerCount)
        try container.encode(weeklyGrowth, forKey: .weeklyGrowth)
        try container.encode(monthlyGrowth, forKey: .monthlyGrowth)
        try container.encode(relatedInterestIds, forKey: .relatedInterestIds)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(synonyms, forKey: .synonyms)
    }
    
    static func from(document: DocumentSnapshot) throws -> Interest? {
        guard var data = document.data() else { return nil }
        data["id"] = document.documentID
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(Interest.self, from: jsonData)
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "name": name,
            "displayName": displayName,
            "parentId": parentId as Any,
            "level": level,
            "path": path,
            "description": description as Any,
            "coverImageUrl": coverImageUrl as Any,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "postCount": postCount,
            "followerCount": followerCount,
            "weeklyGrowth": weeklyGrowth,
            "monthlyGrowth": monthlyGrowth,
            "relatedInterestIds": relatedInterestIds,
            "keywords": keywords,
            "synonyms": synonyms
        ]
    }
}
