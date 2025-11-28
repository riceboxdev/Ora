import Foundation

// MARK: - Authentication Models

/// Admin login response
public struct AdminLoginResponse: Codable {
    public let token: String
    public let admin: AdminUser
    
    enum CodingKeys: String, CodingKey {
        case token
        case admin
    }
}

/// Admin user information
public struct AdminUser: Codable {
    public let id: String
    public let email: String
    public let role: String
    public let firebaseUid: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case firebaseUid
    }
}

// MARK: - User Management Models

/// User information from admin API
public struct AdminUserInfo: Codable {
    public let id: String
    public let email: String?
    public let displayName: String?
    public let photoURL: String?
    public let createdAt: Int64?
    public let isBanned: Bool
    public let isAdmin: Bool
    public let postCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case photoURL
        case createdAt
        case isBanned
        case isAdmin
        case postCount
    }
}

/// Users list response
public struct UsersResponse: Codable {
    public let users: [AdminUserInfo]
    public let count: Int
    public let total: Int?
    public let limit: Int?
    public let offset: Int?
    
    enum CodingKeys: String, CodingKey {
        case users
        case count
        case total
        case limit
        case offset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decode([AdminUserInfo].self, forKey: .users)
        count = try container.decode(Int.self, forKey: .count)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
    }
}

// MARK: - Analytics Models

/// Analytics data response
public struct AnalyticsResponse: Codable {
    public let period: String
    public let users: UserStats
    public let posts: PostStats
    public let engagement: EngagementStats
    
    public struct UserStats: Codable {
        public let total: Int
        public let new: Int
    }
    
    public struct PostStats: Codable {
        public let total: Int
        public let pending: Int
        public let flagged: Int
    }
    
    public struct EngagementStats: Codable {
        public let likes: Int
        public let comments: Int
        public let shares: Int
        public let saves: Int
        public let views: Int
    }
}

// MARK: - Moderation Models

/// Post information for moderation
public struct ModerationPost: Codable {
    public let id: String
    public let userId: String
    public let imageUrl: String?
    public let thumbnailUrl: String?
    public let caption: String?
    public let tags: [String]
    public let moderationStatus: String
    public let createdAt: Int64?
}

/// Moderation queue response
public struct ModerationQueueResponse: Codable {
    public let posts: [ModerationPost]
    public let count: Int
}

// MARK: - Settings Models

/// System settings response
public struct SystemSettingsResponse: Codable {
    public let settings: Settings
    
    public struct Settings: Codable {
        public let featureFlags: [String: Bool]?
        public let remoteConfig: [String: String]?
        public let maintenanceMode: Bool?
    }
}

// MARK: - Report Models

/// Post information in a report
public struct ReportedPost: Codable {
    public let id: String
    public let imageUrl: String?
    public let thumbnailUrl: String?
    public let caption: String?
    public let moderationStatus: String?
    public let moderatedAt: Int64?
    public let moderationReason: String?
}

/// User report information
public struct UserReport: Codable {
    public let id: String
    public let postId: String
    public let reason: String
    public let description: String?
    public let status: String
    public let createdAt: Int64?
    public let post: ReportedPost?
}

/// User reports response
public struct UserReportsResponse: Codable {
    public let reports: [UserReport]
    public let count: Int
}

// MARK: - User Details Models

/// User statistics
public struct UserStats: Codable {
    public let postCount: Int
    public let commentCount: Int
    public let likeCount: Int
    public let followerCount: Int
    public let followingCount: Int
    public let totalEngagements: Int
    public let lastActivityAt: Int64?
}

/// User warning
public struct UserWarning: Codable {
    public let id: String
    public let warningType: String
    public let reason: String
    public let notes: String?
    public let timestamp: Int64?
    public let adminId: String?
}

/// Moderation history entry
public struct ModerationHistoryEntry: Codable {
    public let id: String
    public let action: String
    public let targetType: String
    public let targetId: String
    public let adminId: String?
    public let reason: String?
    public let timestamp: Int64?
}

/// Detailed user information
public struct UserDetailsResponse: Codable {
    public let user: UserDetails
    
    public struct UserDetails: Codable {
        public let id: String
        public let email: String?
        public let username: String?
        public let displayName: String?
        public let photoURL: String?
        public let bio: String?
        public let location: String?
        public let websiteLink: String?
        public let socialLinks: [String: String]?
        public let isAdmin: Bool
        public let isBanned: Bool
        public let bannedAt: Int64?
        public let banReason: String?
        public let createdAt: Int64?
        public let updatedAt: Int64?
        public let isOnboardingCompleted: Bool
        public let stats: UserStats
        public let warnings: [UserWarning]
        public let moderationHistory: [ModerationHistoryEntry]
    }
}

/// User activity entry
public struct UserActivityEntry: Codable {
    public let id: String
    public let type: String // "post" or "comment"
    public let timestamp: Int64?
    public let postId: String
    public let metadata: [String: String]?
}

/// User activity response
public struct UserActivityResponse: Codable {
    public let activities: [UserActivityEntry]
    public let count: Int
    public let total: Int
    public let limit: Int
    public let offset: Int
}

// MARK: - Post Models

/// Post details
public struct PostDetails: Codable {
    public let id: String
    public let activityId: String?
    public let userId: String
    public let username: String?
    public let userProfilePhotoUrl: String?
    public let imageUrl: String?
    public let thumbnailUrl: String?
    public let imageWidth: Int?
    public let imageHeight: Int?
    public let caption: String?
    public let tags: [String]
    public let categories: [String]?
    public let moderationStatus: String
    public let likeCount: Int?
    public let commentCount: Int?
    public let shareCount: Int?
    public let saveCount: Int?
    public let viewCount: Int?
    public let createdAt: Int64?
    public let updatedAt: Int64?
    public let edited: Bool?
    public let moderationReason: String?
    public let moderatedAt: Int64?
    public let moderatedBy: String?
    public let moderationMetadata: [String: String]?
    public let user: PostUserInfo?
    
    public struct PostUserInfo: Codable {
        public let id: String
        public let email: String?
        public let displayName: String?
        public let photoURL: String?
        public let isBanned: Bool?
    }
}

/// Post details response wrapper
public struct PostDetailsResponse: Codable {
    public let post: PostDetails
}

/// Post filters for querying
public struct PostFilters: Codable {
    public let status: String? // "pending", "approved", "rejected", "flagged", "all"
    public let userId: String?
    public let startDate: Int64?
    public let endDate: Int64?
    public let search: String?
    
    public init(status: String? = nil, userId: String? = nil, startDate: Int64? = nil, endDate: Int64? = nil, search: String? = nil) {
        self.status = status
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.search = search
    }
}

/// Posts list response
public struct PostsResponse: Codable {
    public let posts: [PostDetails]
    public let count: Int
    public let total: Int?
    public let limit: Int?
    public let offset: Int?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posts = try container.decode([PostDetails].self, forKey: .posts)
        count = try container.decode(Int.self, forKey: .count)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
    }
}

/// Post update structure
public struct PostUpdate: Codable {
    public let caption: String?
    public let tags: [String]?
    public let moderationStatus: String?
    public let moderationReason: String?
    
    public init(caption: String? = nil, tags: [String]? = nil, moderationStatus: String? = nil, moderationReason: String? = nil) {
        self.caption = caption
        self.tags = tags
        self.moderationStatus = moderationStatus
        self.moderationReason = moderationReason
    }
}

/// Bulk post action
public enum BulkPostAction: String, Codable {
    case approve
    case reject
    case flag
    case delete
}

// MARK: - Settings Update Models

/// System settings update structure
public struct SystemSettingsUpdate: Codable {
    public let featureFlags: [String: Bool]?
    public let remoteConfig: [String: String]?
    public let maintenanceMode: Bool?
    
    public init(featureFlags: [String: Bool]? = nil, remoteConfig: [String: String]? = nil, maintenanceMode: Bool? = nil) {
        self.featureFlags = featureFlags
        self.remoteConfig = remoteConfig
        self.maintenanceMode = maintenanceMode
    }
}

// MARK: - Notification Models

/// Notification creation structure
public struct NotificationCreate: Codable {
    public let title: String
    public let body: String
    public let type: String // "push", "in_app", "email"
    public let audience: String? // "all", "specific", "segment"
    public let audienceIds: [String]?
    public let scheduledFor: Int64?
    public let data: [String: String]?
    
    public init(title: String, body: String, type: String, audience: String? = nil, audienceIds: [String]? = nil, scheduledFor: Int64? = nil, data: [String: String]? = nil) {
        self.title = title
        self.body = body
        self.type = type
        self.audience = audience
        self.audienceIds = audienceIds
        self.scheduledFor = scheduledFor
        self.data = data
    }
}

/// Notification response
public struct NotificationResponse: Codable {
    public let id: String
    public let title: String
    public let body: String
    public let type: String
    public let status: String
    public let createdAt: Int64?
    public let sentAt: Int64?
    public let scheduledFor: Int64?
    public let stats: NotificationStats?
    
    public struct NotificationStats: Codable {
        public let totalRecipients: Int
        public let delivered: Int
        public let opened: Int
        public let clicked: Int
    }
}

/// Notifications list response
public struct NotificationsResponse: Codable {
    public let notifications: [NotificationResponse]
    public let count: Int
    public let success: Bool?
    
    enum CodingKeys: String, CodingKey {
        case notifications
        case success
    }
    
    public init(notifications: [NotificationResponse], count: Int) {
        self.notifications = notifications
        self.count = count
        self.success = nil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notifications = try container.decode([NotificationResponse].self, forKey: .notifications)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        count = notifications.count
    }
}

/// Notification response wrapper
public struct NotificationResponseWrapper: Codable {
    public let success: Bool
    public let notification: NotificationResponse
}

