//
//  AccountSettings.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

struct AccountSettings: Codable {
    @DocumentID var id: String?
    
    // Visibility Settings
    var accountVisibility: String // "public" or "private"
    var profileVisibility: String // "public" or "private"
    var contentVisibility: String // "public" or "private"
    
    // Content Filter Settings
    var blockedTags: [String]?
    var blockedCategories: [String]?
    var blockedLabels: [String]?
    var matureContentFilter: Bool
    
    // Discovery Preferences
    var algorithmPreference: String // "personalized", "trending", "balanced"
    var contentTypePreference: [String]?
    var personalizedWeight: Double
    var trendingWeight: Double
    
    // Language Settings
    var preferredLanguage: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        accountVisibility: String = "public",
        profileVisibility: String = "public",
        contentVisibility: String = "public",
        blockedTags: [String]? = nil,
        blockedCategories: [String]? = nil,
        blockedLabels: [String]? = nil,
        matureContentFilter: Bool = false,
        algorithmPreference: String = "balanced",
        contentTypePreference: [String]? = nil,
        personalizedWeight: Double = 0.5,
        trendingWeight: Double = 0.5,
        preferredLanguage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.accountVisibility = accountVisibility
        self.profileVisibility = profileVisibility
        self.contentVisibility = contentVisibility
        self.blockedTags = blockedTags
        self.blockedCategories = blockedCategories
        self.blockedLabels = blockedLabels
        self.matureContentFilter = matureContentFilter
        self.algorithmPreference = algorithmPreference
        self.contentTypePreference = contentTypePreference
        self.personalizedWeight = personalizedWeight
        self.trendingWeight = trendingWeight
        self.preferredLanguage = preferredLanguage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountVisibility
        case profileVisibility
        case contentVisibility
        case blockedTags
        case blockedCategories
        case blockedLabels
        case matureContentFilter
        case algorithmPreference
        case contentTypePreference
        case personalizedWeight
        case trendingWeight
        case preferredLanguage
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        accountVisibility = try container.decodeIfPresent(String.self, forKey: .accountVisibility) ?? "public"
        profileVisibility = try container.decodeIfPresent(String.self, forKey: .profileVisibility) ?? "public"
        contentVisibility = try container.decodeIfPresent(String.self, forKey: .contentVisibility) ?? "public"
        blockedTags = try container.decodeIfPresent([String].self, forKey: .blockedTags)
        blockedCategories = try container.decodeIfPresent([String].self, forKey: .blockedCategories)
        blockedLabels = try container.decodeIfPresent([String].self, forKey: .blockedLabels)
        matureContentFilter = try container.decodeIfPresent(Bool.self, forKey: .matureContentFilter) ?? false
        algorithmPreference = try container.decodeIfPresent(String.self, forKey: .algorithmPreference) ?? "balanced"
        contentTypePreference = try container.decodeIfPresent([String].self, forKey: .contentTypePreference)
        personalizedWeight = try container.decodeIfPresent(Double.self, forKey: .personalizedWeight) ?? 0.5
        trendingWeight = try container.decodeIfPresent(Double.self, forKey: .trendingWeight) ?? 0.5
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage)
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(accountVisibility, forKey: .accountVisibility)
        try container.encode(profileVisibility, forKey: .profileVisibility)
        try container.encode(contentVisibility, forKey: .contentVisibility)
        try container.encodeIfPresent(blockedTags, forKey: .blockedTags)
        try container.encodeIfPresent(blockedCategories, forKey: .blockedCategories)
        try container.encodeIfPresent(blockedLabels, forKey: .blockedLabels)
        try container.encode(matureContentFilter, forKey: .matureContentFilter)
        try container.encode(algorithmPreference, forKey: .algorithmPreference)
        try container.encodeIfPresent(contentTypePreference, forKey: .contentTypePreference)
        try container.encode(personalizedWeight, forKey: .personalizedWeight)
        try container.encode(trendingWeight, forKey: .trendingWeight)
        try container.encodeIfPresent(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(Timestamp(date: updatedAt), forKey: .updatedAt)
    }
}

