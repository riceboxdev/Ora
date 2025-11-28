//
//  DIContainer.swift
//  OraBeta
//
//  Dependency Injection Container
//  Manages service lifecycle and provides shared instances
//

import Foundation
import SwiftUI
import Combine

/// Dependency Injection Container
/// Provides centralized access to all app services with proper lifecycle management
@MainActor
final class DIContainer: ObservableObject {
    /// Shared singleton instance
    static let shared = DIContainer()
    
    // MARK: - Authentication Services
    
    /// Authentication service for Firebase Auth
    private(set) lazy var authService: AuthServiceProtocol = {
        AuthService()
    }()
    
    // MARK: - Core Services (No Dependencies)
    
    /// Profile service with caching
    private(set) lazy var profileService: ProfileServiceProtocol = {
        ProfileService()
    }()
    
    /// Board service for collections
    private(set) lazy var boardService: BoardService = {
        BoardService()
    }()
    
    /// Like service for post likes
    private(set) lazy var likeService: LikeService = {
        LikeService()
    }()
    
    /// Comment service for post comments
    private(set) lazy var commentService: CommentService = {
        CommentService()
    }()
    
    /// User preference service
    private(set) lazy var userPreferenceService: UserPreferenceService = {
        UserPreferenceService()
    }()
    
    /// Image upload service
    private(set) lazy var imageUploadService: ImageUploadService = {
        ImageUploadService()
    }()
    
    /// Image migration service
    private(set) lazy var imageMigrationService: ImageMigrationService = {
        ImageMigrationService()
    }()
    
    /// Feed analytics service
    private(set) lazy var feedAnalyticsService: FeedAnalyticsService = {
        FeedAnalyticsService()
    }()
    
    // MARK: - Dependent Services
    
    /// Post service (depends on ProfileService)
    private(set) lazy var postService: PostServiceProtocol = {
        PostService(profileService: profileService as! ProfileService)
    }()
    
    /// Feed service (depends on ProfileService)
    private(set) lazy var feedService: FeedServiceProtocol = {
        FeedService(profileService: profileService as! ProfileService)
    }()
    
    /// Engagement service (depends on LikeService, CommentService, BoardService)
    private(set) lazy var engagementService: EngagementService = {
        EngagementService(
            likeService: likeService,
            commentService: commentService,
            boardService: boardService
        )
    }()
    
    // MARK: - Singleton Services
    
    /// Tag service (singleton)
    var tagService: TagService {
        TagService.shared
    }
    
    /// Algolia search service (singleton)
    var algoliaSearchService: AlgoliaSearchService {
        AlgoliaSearchService.shared
    }
    
    /// Algolia recommend service (singleton)
    var algoliaRecommendService: AlgoliaRecommendService {
        AlgoliaRecommendService.shared
    }
    
    /// Algolia insights service (singleton)
    var algoliaInsightsService: AlgoliaInsightsService {
        AlgoliaInsightsService.shared
    }
    
    /// Post analysis service (singleton)
    var postAnalysisService: PostAnalysisService {
        PostAnalysisService.shared
    }
    
    /// Trend service (singleton)
    var trendService: TrendService {
        TrendService.shared
    }
    
    /// Notification manager (singleton)
    var notificationManager: NotificationManager {
        NotificationManager.shared
    }
    
    /// Upload queue service (singleton)
    var uploadQueueService: UploadQueueService {
        UploadQueueService.shared
    }
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to enforce singleton pattern
    }
}

// MARK: - SwiftUI Environment Support

extension DIContainer {
    /// Create environment values for dependency injection in SwiftUI views
    struct DIContainerKey: EnvironmentKey {
        static let defaultValue = DIContainer.shared
    }
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainer.DIContainerKey.self] }
        set { self[DIContainer.DIContainerKey.self] = newValue }
    }
}

