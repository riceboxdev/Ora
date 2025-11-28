//
//  StoryServiceFactory.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

// MARK: - Story Service Factory
class StoryServiceFactory {
    private let configuration: StoryConfiguration
    private let logger: StoryLoggingProtocol
    
    init(configuration: StoryConfiguration = .default, logger: StoryLoggingProtocol? = nil) {
        self.configuration = configuration
        self.logger = logger ?? StoryLogger(configuration: configuration)
    }
    
    func makeStoryService(
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) -> StoryServiceProtocol {
        #if DEBUG
        if configuration == .development {
            return makeDevelopmentStoryService(profileService: profileService, postService: postService)
        }
        #endif
        
        return makeProductionStoryService(profileService: profileService, postService: postService)
    }
    
    func makeRepository() -> StoryRepositoryProtocol {
        return StoryRepository(logger: logger)
    }
    
    func makeCache() -> StoryCacheProtocol {
        return StoryCache(logger: logger)
    }
    
    func makeAnalytics() -> StoryAnalyticsProtocol {
        return StoryAnalytics(configuration: configuration, logger: logger)
    }
    
    // MARK: - Private Factory Methods
    private func makeProductionStoryService(
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) -> StoryServiceProtocol {
        let repository = makeRepository()
        let cache = makeCache()
        let analytics = makeAnalytics()
        
        return EnhancedStoryService(
            configuration: configuration,
            repository: repository,
            cache: cache,
            analytics: analytics,
            logger: logger,
            profileService: profileService,
            postService: postService
        )
    }
    
    #if DEBUG
    private func makeDevelopmentStoryService(
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) -> StoryServiceProtocol {
        let repository = makeRepository()
        let cache = makeCache()
        let analytics = MockStoryAnalytics()
        
        return EnhancedStoryService(
            configuration: configuration,
            repository: repository,
            cache: cache,
            analytics: analytics,
            logger: logger,
            profileService: profileService,
            postService: postService
        )
    }
    #endif
}

// MARK: - Story Service Container
class StoryServiceContainer {
    static let shared = StoryServiceContainer()
    
    private let factory: StoryServiceFactory
    private var _storyService: StoryServiceProtocol?
    
    private init() {
        #if DEBUG
        let config = StoryConfiguration.development
        #else
        let config = StoryConfiguration.default
        #endif
        
        self.factory = StoryServiceFactory(configuration: config)
    }
    
    var storyService: StoryServiceProtocol {
        get {
            if let service = _storyService {
                return service
            }
            
            let service = factory.makeStoryService(
                profileService: DIContainer.shared.profileService,
                postService: DIContainer.shared.postService
            )
            
            _storyService = service
            return service
        }
        set {
            _storyService = newValue
        }
    }
    
    func reset() {
        _storyService = nil
    }
}
