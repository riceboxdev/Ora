//
//  StoryPackage.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

// MARK: - Story Package Root
/// The main entry point for the Story package
/// This structure provides a clean API for external consumption
struct StoryPackage {
    
    // MARK: - Configuration
    static func configure(
        configuration: StoryConfiguration = .default,
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) {
        let container = StoryServiceContainer.shared
        container.reset()
        
        // Update the factory with new configuration
        let factory = StoryServiceFactory(configuration: configuration)
        let service = factory.makeStoryService(
            profileService: profileService,
            postService: postService
        )
        
        // Store the service
        container.storyService = service
    }
    
    // MARK: - API
    static func createStoryService(
        configuration: StoryConfiguration = .default,
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) -> StoryServiceProtocol {
        let factory = StoryServiceFactory(configuration: configuration)
        return factory.makeStoryService(
            profileService: profileService,
            postService: postService
        )
    }
    
    static func createStoryViewModel(
        storyService: StoryServiceProtocol? = nil
    ) -> StoryViewModel {
        return StoryViewModel(storyService: storyService)
    }
    
    static func createStoryPreviewViewModel(
        storyService: StoryServiceProtocol? = nil
    ) -> StoryPreviewViewModel {
        return StoryPreviewViewModel(storyService: storyService)
    }
}

// MARK: - Package Exports
// These are the interfaces that would be exposed in a Swift Package

// Models
typealias StoryPackageModels = (
    Story: Story.Type,
    StoryItem: StoryItem.Type,
    CreateStoryRequest: CreateStoryRequest.Type
)

// Services
typealias StoryPackageServices = (
    StoryServiceProtocol: StoryServiceProtocol.Type,
    StoryRepositoryProtocol: StoryRepositoryProtocol.Type,
    StoryCacheProtocol: StoryCacheProtocol.Type,
    StoryAnalyticsProtocol: StoryAnalyticsProtocol.Type
)

// ViewModels
typealias StoryPackageViewModels = (
    StoryViewModel: StoryViewModel.Type,
    StoryPreviewViewModel: StoryPreviewViewModel.Type
)

// Configuration
typealias StoryPackageConfiguration = (
    StoryConfiguration: StoryConfiguration.Type,
    StoryError: StoryError.Type,
    StoryAnalyticsEvent: StoryAnalyticsEvent.Type
)

// MARK: - Package Info
struct StoryPackageInfo {
    static let name = "StoryPackage"
    static let version = "1.0.0"
    static let description = "A robust, extensible story system for iOS apps"
    
    static var features: [String] {
        return [
            "Story creation from posts",
            "Story viewing and tracking",
            "Automatic expiration and cleanup",
            "Caching layer for performance",
            "Analytics integration",
            "Comprehensive error handling",
            "Configurable settings",
            "Extensible architecture"
        ]
    }
}
