//
//  Interest.swift
//  OraBeta
//
//  Pinterest-style hierarchical interest taxonomy model
//

import Foundation
import FirebaseFirestore

/// Represents a node in the hierarchical interest taxonomy
/// Based on Pinterest's Interest Taxonomy structure
struct Interest: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String                    // Canonical name (normalized, lowercase)
    let displayName: String             // Display name (proper capitalization)
    let parentId: String?               // nil for root-level interests
    let level: Int                      // Depth in hierarchy (0 = root)
    let path: [String]                  // Full path from root (e.g., ["fashion", "models", "runway"])
    let description: String?
    let coverImageUrl: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Statistics
    let postCount: Int
    let followerCount: Int
    let weeklyGrowth: Double
    let monthlyGrowth: Double
    
    // Taxonomy metadata
    let relatedInterestIds: [String]    // Suggested related interests
    let keywords: [String]              // For matching: ["runway", "catwalk", "fashion week"]
    let synonyms: [String]              // Alternative terms
    
    init(
        id: String,
        name: String,
        displayName: String,
        parentId: String? = nil,
        level: Int,
        path: [String],
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
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, parentId, level, path
        case description, coverImageUrl, isActive
        case createdAt, updatedAt
        case postCount, followerCount, weeklyGrowth, monthlyGrowth
        case relatedInterestIds, keywords, synonyms
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
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        
        // Handle Timestamp from Firestore
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
        
        postCount = try container.decodeIfPresent(Int.self, forKey: .postCount) ?? 0
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0
        weeklyGrowth = try container.decodeIfPresent(Double.self, forKey: .weeklyGrowth) ?? 0.0
        monthlyGrowth = try container.decodeIfPresent(Double.self, forKey: .monthlyGrowth) ?? 0.0
        relatedInterestIds = try container.decodeIfPresent([String].self, forKey: .relatedInterestIds) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
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
    
    // MARK: - Computed Properties
    
    /// Whether this is a root-level interest
    var isRoot: Bool {
        return parentId == nil && level == 0
    }
    
    /// Whether this interest has children (not directly stored, need to query)
    var hasChildren: Bool {
        // This would need to be set by the service when fetching
        return false
    }
    
    /// Full display path (e.g., "Fashion > Models > Runway")
    var displayPath: String {
        return path.map { $0.capitalized }.joined(separator: " > ")
    }
    
    // MARK: - Factory Methods
    
    /// Create Interest from Firestore document
    static func from(document: DocumentSnapshot) throws -> Interest? {
        guard let data = document.data() else { return nil }
        return try from(dictionary: data, id: document.documentID)
    }
    
    /// Create Interest from dictionary
    static func from(dictionary: [String: Any], id: String) throws -> Interest {
        let name = dictionary["name"] as? String ?? ""
        let displayName = dictionary["displayName"] as? String ?? name.capitalized
        let parentId = dictionary["parentId"] as? String
        let level = dictionary["level"] as? Int ?? 0
        let path = dictionary["path"] as? [String] ?? [name]
        let description = dictionary["description"] as? String
        let coverImageUrl = dictionary["coverImageUrl"] as? String
        let isActive = dictionary["isActive"] as? Bool ?? true
        
        var createdAt = Date()
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            createdAt = date
        }
        
        var updatedAt = Date()
        if let timestamp = dictionary["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else if let date = dictionary["updatedAt"] as? Date {
            updatedAt = date
        }
        
        let postCount = dictionary["postCount"] as? Int ?? 0
        let followerCount = dictionary["followerCount"] as? Int ?? 0
        let weeklyGrowth = dictionary["weeklyGrowth"] as? Double ?? 0.0
        let monthlyGrowth = dictionary["monthlyGrowth"] as? Double ?? 0.0
        let relatedInterestIds = dictionary["relatedInterestIds"] as? [String] ?? []
        let keywords = dictionary["keywords"] as? [String] ?? []
        let synonyms = dictionary["synonyms"] as? [String] ?? []
        
        return Interest(
            id: id,
            name: name,
            displayName: displayName,
            parentId: parentId,
            level: level,
            path: path,
            description: description,
            coverImageUrl: coverImageUrl,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            postCount: postCount,
            followerCount: followerCount,
            weeklyGrowth: weeklyGrowth,
            monthlyGrowth: monthlyGrowth,
            relatedInterestIds: relatedInterestIds,
            keywords: keywords,
            synonyms: synonyms
        )
    }
    
    /// Convert to Firestore dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name,
            "displayName": displayName,
            "level": level,
            "path": path,
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
        
        if let parentId = parentId {
            data["parentId"] = parentId
        }
        if let description = description {
            data["description"] = description
        }
        if let coverImageUrl = coverImageUrl {
            data["coverImageUrl"] = coverImageUrl
        }
        
        return data
    }
}

// MARK: - Interest Candidate (for mining new interests)

extension Interest {
    struct Candidate {
        let name: String
        let keywords: [String]
        let occurenceCount: Int
        let proposedParentId: String?
        let proposedLevel: Int
    }
}
