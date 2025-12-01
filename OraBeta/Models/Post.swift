//
//  Post.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
internal import CoreGraphics

struct Post: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let activityId: String
    let userId: String
    let username: String?
    let userProfilePhotoUrl: String?
    let imageUrl: String
    let thumbnailUrl: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let caption: String?
    let tags: [String]?                     // User-provided freeform tags
    let categories: [String]?               // Legacy (deprecated)
    
    // Interest classification (Pin2Interest)
    let interestIds: [String]?              // Classified interest IDs
    let interestScores: [String: Double]?   // Interest ID → confidence score
    let primaryInterestId: String?          // Main interest (highest confidence)
    
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let shareCount: Int
    let saveCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case activityId
        case userId
        case username
        case userProfilePhotoUrl
        case imageUrl
        case thumbnailUrl
        case imageWidth
        case imageHeight
        case caption
        case tags
        case categories
        case interestIds
        case interestScores
        case primaryInterestId
        case likeCount
        case commentCount
        case viewCount
        case shareCount
        case saveCount
        case createdAt
    }
    
    init(
        activityId: String,
        userId: String,
        username: String? = nil,
        userProfilePhotoUrl: String? = nil,
        imageUrl: String,
        thumbnailUrl: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        caption: String? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil,
        interestIds: [String]? = nil,
        interestScores: [String: Double]? = nil,
        primaryInterestId: String? = nil,
        likeCount: Int = 0,
        commentCount: Int = 0,
        viewCount: Int = 0,
        shareCount: Int = 0,
        saveCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = activityId
        self.activityId = activityId
        self.userId = userId
        self.username = username
        self.userProfilePhotoUrl = userProfilePhotoUrl
        self.imageUrl = imageUrl
        self.thumbnailUrl = thumbnailUrl
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.caption = caption
        self.tags = tags
        self.categories = categories
        self.interestIds = interestIds
        self.interestScores = interestScores
        self.primaryInterestId = primaryInterestId
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.viewCount = viewCount
        self.shareCount = shareCount
        self.saveCount = saveCount
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId) ?? id
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        userProfilePhotoUrl = try container.decodeIfPresent(String.self, forKey: .userProfilePhotoUrl)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        interestIds = try container.decodeIfPresent([String].self, forKey: .interestIds)
        interestScores = try container.decodeIfPresent([String: Double].self, forKey: .interestScores)
        primaryInterestId = try container.decodeIfPresent(String.self, forKey: .primaryInterestId)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
        
        // Handle createdAt - can be Timestamp or Date
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(activityId, forKey: .activityId)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(userProfilePhotoUrl, forKey: .userProfilePhotoUrl)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(categories, forKey: .categories)
        try container.encodeIfPresent(interestIds, forKey: .interestIds)
        try container.encodeIfPresent(interestScores, forKey: .interestScores)
        try container.encodeIfPresent(primaryInterestId, forKey: .primaryInterestId)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(shareCount, forKey: .shareCount)
        try container.encode(saveCount, forKey: .saveCount)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    // MARK: - Computed Properties for Image Dimensions
    
    /// Check if image dimensions are available
    var hasDimensions: Bool {
        return imageWidth != nil && imageHeight != nil
    }
    
    /// Get aspect ratio of the image (width/height)
    /// Returns nil if dimensions are not available
    var aspectRatio: Double? {
        guard let width = imageWidth, let height = imageHeight, height > 0 else {
            return nil
        }
        return Double(width) / Double(height)
    }
    
    /// Get image size as CGSize
    /// Returns nil if dimensions are not available
    var imageSize: CGSize? {
        guard let width = imageWidth, let height = imageHeight else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
    
    /// Determine image orientation
    var isLandscape: Bool {
        guard let ratio = aspectRatio else { return false }
        return ratio > 1.0
    }
    
    var isPortrait: Bool {
        guard let ratio = aspectRatio else { return false }
        return ratio < 1.0
    }
    
    var isSquare: Bool {
        guard let ratio = aspectRatio else { return false }
        return abs(ratio - 1.0) < 0.01 // Allow small tolerance for rounding
    }
    
    /// Get thumbnail URL, generating it from imageUrl if needed
    var effectiveThumbnailUrl: String {
        // Check if we have a stored thumbnail URL (optimized)
        if let thumbnailUrl = thumbnailUrl, !thumbnailUrl.isEmpty, thumbnailUrl != imageUrl {
            // Check if the stored thumbnail URL is malformed for Cloudflare Images
            if thumbnailUrl.contains("imagedelivery.net") && thumbnailUrl.contains("/cdn-cgi/image/") {
                // Fall through to generate correct URL from imageUrl
            } else {
                return thumbnailUrl
            }
        }
        
        // For Cloudflare Images, try to generate optimized URL
        if imageUrl.contains("imagedelivery.net") || imageUrl.contains("cloudflare.com") {
            let optimizedUrl = generateCloudflareThumbnailUrl(from: imageUrl)
            if optimizedUrl != imageUrl {
                return optimizedUrl
            }
        }
        
        // Fallback to imageUrl if no thumbnail is available
        return imageUrl
    }
    
    /// Generate Cloudflare thumbnail URL from image URL
    private func generateCloudflareThumbnailUrl(from imageUrl: String) -> String {
        // Without Cloudflare variant/transformation support, use the same URL
        // CachedImageView will downsample for display
        return imageUrl
    }
    
    /// Create Post from Stream Activity (Activity is a generic type from Stream SDK)
    /// - Parameters:
    ///   - activity: Stream activity dictionary
    ///   - profiles: Pre-fetched profiles dictionary (userId -> UserProfile) for efficiency
    ///   - profileService: Optional ProfileService for fallback fetching (only used if profiles dictionary is nil)
    static func from(activity: [String: Any], profiles: [String: UserProfile]? = nil, profileService: ProfileService? = nil) async -> Post? {
        guard let actor = activity["actor"] as? String,
              let actorId = actor.components(separatedBy: ":").last,
              let activityId = activity["id"] as? String else {
            return nil
        }
        
        let custom = activity["custom"] as? [String: Any]
        let imageUrl = custom?["imageUrl"] as? String ?? ""
        let thumbnailUrl = custom?["thumbnailUrl"] as? String
        let imageWidth = custom?["imageWidth"] as? Int ?? custom?["width"] as? Int
        let imageHeight = custom?["imageHeight"] as? Int ?? custom?["height"] as? Int
        let caption = custom?["text"] as? String ?? custom?["caption"] as? String
        let tags = custom?["tags"] as? [String]
        let categories = custom?["categories"] as? [String]
        
        var username: String?
        var userProfilePhotoUrl: String?
        
        // Use pre-fetched profiles if available (more efficient)
        if let profiles = profiles, let profile = profiles[actorId] {
            username = profile.username
            userProfilePhotoUrl = profile.profilePhotoUrl
        } else if let profileService = profileService {
            // Fallback to fetching profile individually (less efficient)
            if let profile = try? await profileService.getUserProfile(userId: actorId) {
                username = profile.username
                userProfilePhotoUrl = profile.profilePhotoUrl
            }
        }
        
        let timeString = activity["time"] as? String
        let createdAt = timeString.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        
        return Post(
            activityId: activityId,
            userId: actorId,
            username: username,
            userProfilePhotoUrl: userProfilePhotoUrl,
            imageUrl: imageUrl,
            thumbnailUrl: thumbnailUrl,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            caption: caption,
            tags: tags,
            categories: categories,
            interestIds: nil,
            interestScores: nil,
            primaryInterestId: nil,
            likeCount: 0,
            commentCount: 0,
            viewCount: 0,
            shareCount: 0,
            saveCount: 0,
            createdAt: createdAt
        )
    }
    
    /// Create Post from Firestore document
    /// - Parameters:
    ///   - firestoreData: Firestore document data
    ///   - documentId: Firestore document ID
    ///   - profiles: Pre-fetched profiles dictionary (userId -> UserProfile) for efficiency
    ///   - profileService: Optional ProfileService for fallback fetching (only used if profiles dictionary is nil)
    static func from(firestoreData: [String: Any], documentId: String, profiles: [String: UserProfile]? = nil, profileService: ProfileService? = nil) async -> Post? {
        guard let userId = firestoreData["userId"] as? String,
              let imageUrl = firestoreData["imageUrl"] as? String else {
            return nil
        }
        
        let activityId = firestoreData["activityId"] as? String ?? documentId
        let thumbnailUrl = firestoreData["thumbnailUrl"] as? String
        let imageWidth = firestoreData["imageWidth"] as? Int
        let imageHeight = firestoreData["imageHeight"] as? Int
        let caption = firestoreData["caption"] as? String
        let tags = firestoreData["tags"] as? [String]
        let categories = firestoreData["categories"] as? [String]
        let interestIds = firestoreData["interestIds"] as? [String]
        let interestScores = firestoreData["interestScores"] as? [String: Double]
        let primaryInterestId = firestoreData["primaryInterestId"] as? String
        let likeCount = firestoreData["likeCount"] as? Int ?? 0
        let commentCount = firestoreData["commentCount"] as? Int ?? 0
        let viewCount = firestoreData["viewCount"] as? Int ?? 0
        let shareCount = firestoreData["shareCount"] as? Int ?? 0
        let saveCount = firestoreData["saveCount"] as? Int ?? 0
        
        // Parse createdAt
        var createdAt = Date()
        if let timestamp = firestoreData["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = firestoreData["createdAt"] as? Date {
            createdAt = date
        }
        
        var username: String?
        var userProfilePhotoUrl: String?
        
        // Use pre-fetched profiles if available (more efficient)
        if let profiles = profiles, let profile = profiles[userId] {
            username = profile.username
            userProfilePhotoUrl = profile.profilePhotoUrl
        } else if let profileService = profileService {
            // Fallback to fetching profile individually (less efficient)
            if let profile = try? await profileService.getUserProfile(userId: userId) {
                username = profile.username
                userProfilePhotoUrl = profile.profilePhotoUrl
            }
        }
        
        return Post(
            activityId: activityId,
            userId: userId,
            username: username,
            userProfilePhotoUrl: userProfilePhotoUrl,
            imageUrl: imageUrl,
            thumbnailUrl: thumbnailUrl,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            caption: caption,
            tags: tags,
            categories: categories,
            interestIds: interestIds,
            interestScores: interestScores,
            primaryInterestId: primaryInterestId,
            likeCount: likeCount,
            commentCount: commentCount,
            viewCount: viewCount,
            shareCount: shareCount,
            saveCount: saveCount,
            createdAt: createdAt
        )
    }
}

