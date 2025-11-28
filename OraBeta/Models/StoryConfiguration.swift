//
//  StoryConfiguration.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

// MARK: - Story Configuration
struct StoryConfiguration: Equatable {
    let storyDuration: TimeInterval // Default: 24 hours
    let maxStoriesPerUser: Int
    let autoCleanupInterval: TimeInterval
    let enableAnalytics: Bool
    let enableViewTracking: Bool
    
    static let `default` = StoryConfiguration(
        storyDuration: 24 * 60 * 60, // 24 hours
        maxStoriesPerUser: 10,
        autoCleanupInterval: 60 * 60, // 1 hour
        enableAnalytics: true,
        enableViewTracking: true
    )
    
    static let development = StoryConfiguration(
        storyDuration: 5 * 60, // 5 minutes for testing
        maxStoriesPerUser: 5,
        autoCleanupInterval: 5 * 60, // 5 minutes
        enableAnalytics: false,
        enableViewTracking: true
    )
    
    init(
        storyDuration: TimeInterval,
        maxStoriesPerUser: Int,
        autoCleanupInterval: TimeInterval,
        enableAnalytics: Bool,
        enableViewTracking: Bool
    ) {
        self.storyDuration = storyDuration
        self.maxStoriesPerUser = maxStoriesPerUser
        self.autoCleanupInterval = autoCleanupInterval
        self.enableAnalytics = enableAnalytics
        self.enableViewTracking = enableViewTracking
    }
}

// MARK: - Story Error Types
enum StoryError: LocalizedError, Equatable {
    case configurationError(String)
    case networkError(Error)
    case validationError(String)
    case permissionError(String)
    case resourceNotFound(String)
    case duplicateResource(String)
    case serviceUnavailable(String)
    case timeoutError
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .permissionError(let message):
            return "Permission denied: \(message)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        case .duplicateResource(let resource):
            return "Resource already exists: \(resource)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        case .timeoutError:
            return "Request timed out"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again"
        case .permissionError:
            return "Please check your permissions and try again"
        case .serviceUnavailable:
            return "Please try again later"
        case .timeoutError:
            return "Please check your connection and try again"
        default:
            return "Please try again"
        }
    }
    
    static func == (lhs: StoryError, rhs: StoryError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationError(let lhsMessage), .validationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.permissionError(let lhsMessage), .permissionError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.resourceNotFound(let lhsResource), .resourceNotFound(let rhsResource)):
            return lhsResource == rhsResource
        case (.duplicateResource(let lhsResource), .duplicateResource(let rhsResource)):
            return lhsResource == rhsResource
        case (.serviceUnavailable(let lhsService), .serviceUnavailable(let rhsService)):
            return lhsService == rhsService
        case (.unknownError(let lhsMessage), .unknownError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.timeoutError, .timeoutError):
            return true
        case (.networkError, .networkError):
            return true // Can't compare Error instances, just check type
        default:
            return false
        }
    }
}

// MARK: - Story Result Type
typealias StoryResult<T> = Result<T, StoryError>

// MARK: - Story Analytics Events
enum StoryAnalyticsEvent {
    case storyCreated(userId: String, postId: String)
    case storyViewed(storyId: String, userId: String)
    case storyExpired(storyId: String)
    case storyDeleted(storyId: String, userId: String)
    case storyError(error: StoryError, context: String)
    
    var name: String {
        switch self {
        case .storyCreated:
            return "story_created"
        case .storyViewed:
            return "story_viewed"
        case .storyExpired:
            return "story_expired"
        case .storyDeleted:
            return "story_deleted"
        case .storyError:
            return "story_error"
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .storyCreated(let userId, let postId):
            return ["user_id": userId, "post_id": postId]
        case .storyViewed(let storyId, let userId):
            return ["story_id": storyId, "user_id": userId]
        case .storyExpired(let storyId):
            return ["story_id": storyId]
        case .storyDeleted(let storyId, let userId):
            return ["story_id": storyId, "user_id": userId]
        case .storyError(let error, let context):
            return [
                "error_type": String(describing: error),
                "error_message": error.errorDescription ?? "",
                "context": context
            ]
        }
    }
}
