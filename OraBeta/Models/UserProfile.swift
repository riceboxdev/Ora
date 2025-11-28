//
//  UserProfile.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var username: String
    var displayName: String?
    var bio: String?
    var profilePhotoUrl: String?
    var websiteLink: String?
    var location: String?
    var socialLinks: [String: String]?
    var isAdmin: Bool
    var followerCount: Int
    var followingCount: Int
    var createdAt: Date
    var isOnboardingCompleted: Bool // Whether user has completed onboarding flow
    
    // User Preference Fields
    var preferredLabels: [String]? // Semantic labels user is interested in
    var preferredTags: [String]? // Tags user follows
    var preferredCategories: [String]? // Categories user likes
    var labelWeights: [String: Double]? // Label -> weight (engagement frequency)
    var tagWeights: [String: Double]? // Tag -> weight
    var categoryWeights: [String: Double]? // Category -> weight
    var lastPreferencesUpdate: Date? // Last time preferences were updated
    var totalEngagements: Int // Total likes + comments + saves + shares
    var preferenceVersion: Int // Version number for preference schema
    
    init(
        id: String? = nil,
        email: String,
        username: String,
        displayName: String? = nil,
        bio: String? = nil,
        profilePhotoUrl: String? = nil,
        websiteLink: String? = nil,
        location: String? = nil,
        socialLinks: [String: String]? = nil,
        isAdmin: Bool = false,
        followerCount: Int = 0,
        followingCount: Int = 0,
        createdAt: Date = Date(),
        isOnboardingCompleted: Bool = false,
        preferredLabels: [String]? = nil,
        preferredTags: [String]? = nil,
        preferredCategories: [String]? = nil,
        labelWeights: [String: Double]? = nil,
        tagWeights: [String: Double]? = nil,
        categoryWeights: [String: Double]? = nil,
        lastPreferencesUpdate: Date? = nil,
        totalEngagements: Int = 0,
        preferenceVersion: Int = 1
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.profilePhotoUrl = profilePhotoUrl
        self.websiteLink = websiteLink
        self.location = location
        self.socialLinks = socialLinks
        self.isAdmin = isAdmin
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.createdAt = createdAt
        self.isOnboardingCompleted = isOnboardingCompleted
        self.preferredLabels = preferredLabels
        self.preferredTags = preferredTags
        self.preferredCategories = preferredCategories
        self.labelWeights = labelWeights
        self.tagWeights = tagWeights
        self.categoryWeights = categoryWeights
        self.lastPreferencesUpdate = lastPreferencesUpdate
        self.totalEngagements = totalEngagements
        self.preferenceVersion = preferenceVersion
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName
        case bio
        case profilePhotoUrl
        case websiteLink
        case location
        case socialLinks
        case isAdmin
        case followerCount
        case followingCount
        case createdAt
        case isOnboardingCompleted
        case preferredLabels
        case preferredTags
        case preferredCategories
        case labelWeights
        case tagWeights
        case categoryWeights
        case lastPreferencesUpdate
        case totalEngagements
        case preferenceVersion
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // @DocumentID will be automatically populated from the document ID when reading from Firestore
        // We can optionally decode it, but Firestore handles it automatically
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        profilePhotoUrl = try container.decodeIfPresent(String.self, forKey: .profilePhotoUrl)
        websiteLink = try container.decodeIfPresent(String.self, forKey: .websiteLink)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        socialLinks = try container.decodeIfPresent([String: String].self, forKey: .socialLinks)
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        
        // Handle createdAt - can be Timestamp or Date
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        isOnboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .isOnboardingCompleted) ?? false
        
        // Decode preference fields
        preferredLabels = try container.decodeIfPresent([String].self, forKey: .preferredLabels)
        preferredTags = try container.decodeIfPresent([String].self, forKey: .preferredTags)
        preferredCategories = try container.decodeIfPresent([String].self, forKey: .preferredCategories)
        labelWeights = try container.decodeIfPresent([String: Double].self, forKey: .labelWeights)
        tagWeights = try container.decodeIfPresent([String: Double].self, forKey: .tagWeights)
        categoryWeights = try container.decodeIfPresent([String: Double].self, forKey: .categoryWeights)
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .lastPreferencesUpdate) {
            lastPreferencesUpdate = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .lastPreferencesUpdate) {
            lastPreferencesUpdate = date
        }
        
        totalEngagements = try container.decodeIfPresent(Int.self, forKey: .totalEngagements) ?? 0
        preferenceVersion = try container.decodeIfPresent(Int.self, forKey: .preferenceVersion) ?? 1
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Don't encode id - @DocumentID is managed by Firestore based on document path
        // try container.encodeIfPresent(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(profilePhotoUrl, forKey: .profilePhotoUrl)
        try container.encodeIfPresent(websiteLink, forKey: .websiteLink)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encode(followerCount, forKey: .followerCount)
        try container.encode(followingCount, forKey: .followingCount)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(isOnboardingCompleted, forKey: .isOnboardingCompleted)
        
        // Encode preference fields
        try container.encodeIfPresent(preferredLabels, forKey: .preferredLabels)
        try container.encodeIfPresent(preferredTags, forKey: .preferredTags)
        try container.encodeIfPresent(preferredCategories, forKey: .preferredCategories)
        try container.encodeIfPresent(labelWeights, forKey: .labelWeights)
        try container.encodeIfPresent(tagWeights, forKey: .tagWeights)
        try container.encodeIfPresent(categoryWeights, forKey: .categoryWeights)
        
        if let lastUpdate = lastPreferencesUpdate {
            try container.encode(Timestamp(date: lastUpdate), forKey: .lastPreferencesUpdate)
        }
        
        try container.encode(totalEngagements, forKey: .totalEngagements)
        try container.encode(preferenceVersion, forKey: .preferenceVersion)
    }
}

