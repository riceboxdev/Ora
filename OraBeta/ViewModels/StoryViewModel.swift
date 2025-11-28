//
//  StoryViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import Combine
import FirebaseAuth

/// ViewModel for managing story-related operations and UI state
@MainActor
class StoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var storyItems: [StoryItem] = []
    @Published var currentUserStory: StoryItem?
    @Published var error: StoryError?
    @Published var hasError = false
    
    // MARK: - Private Properties
    private let storyService: StoryServiceProtocol
    private let logger: StoryLoggingProtocol
    
    // MARK: - Initialization
    init(
        storyService: StoryServiceProtocol? = nil,
        logger: StoryLoggingProtocol? = nil
    ) {
        self.storyService = storyService ?? StoryServiceContainer.shared.storyService
        self.logger = logger ?? StoryLogger()
    }
    
    // MARK: - Public Methods
    func loadStories() async {
        await loadStories(for: Auth.auth().currentUser?.uid)
    }
    
    func loadStories(for userId: String?) async {
        guard let userId = userId else {
            setError(.validationError("User not authenticated"))
            return
        }
        
        setLoading(true)
        clearError()
        
        do {
            // Load current user's story
            let userStories = try await storyService.getStoryItemsForUser(userId: userId)
            currentUserStory = userStories.first
            
            // Load stories from following
            let followingStories = try await storyService.getStoryItemsFromFollowing(userId: userId)
            storyItems = followingStories
            
            logger.logInfo("Loaded \(userStories.count) user stories and \(followingStories.count) following stories", category: "ViewModel")
            
        } catch let storyError as StoryError {
            setError(storyError)
        } catch {
            setError(.unknownError(error.localizedDescription))
        }
        
        setLoading(false)
    }
    
    func refreshStories() async {
        await loadStories()
    }
    
    func createStory(from post: Post) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            setError(.validationError("User not authenticated"))
            return false
        }
        
        setLoading(true)
        clearError()
        
        do {
            let request = CreateStoryRequest(postId: post.id, userId: userId)
            _ = try await storyService.createStory(request: request)
            
            logger.logInfo("Story created successfully for post: \(post.id)", category: "ViewModel")
            
            // Refresh stories after creation
            await loadStories()
            return true
            
        } catch let storyError as StoryError {
            setError(storyError)
            return false
        } catch {
            setError(.unknownError(error.localizedDescription))
            return false
        }
    }
    
    func markStoryAsViewed(_ storyItem: StoryItem) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            setError(.validationError("User not authenticated"))
            return
        }
        
        do {
            try await storyService.markStoryAsViewed(storyId: storyItem.story.id!, userId: userId)
            
            // Update local state
            if let index = storyItems.firstIndex(where: { $0.id == storyItem.id }) {
                storyItems[index] = storyItem
            }
            
            logger.logInfo("Story marked as viewed: \(storyItem.id)", category: "ViewModel")
            
        } catch let storyError as StoryError {
            setError(storyError)
        } catch {
            setError(.unknownError(error.localizedDescription))
        }
    }
    
    func deleteStory(_ storyItem: StoryItem) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            setError(.validationError("User not authenticated"))
            return false
        }
        
        // Only allow users to delete their own stories
        guard storyItem.story.userId == userId else {
            setError(.permissionError("You can only delete your own stories"))
            return false
        }
        
        setLoading(true)
        clearError()
        
        do {
            try await storyService.deleteStory(storyId: storyItem.story.id!)
            
            logger.logInfo("Story deleted successfully: \(storyItem.id)", category: "ViewModel")
            
            // Refresh stories after deletion
            await loadStories()
            return true
            
        } catch let storyError as StoryError {
            setError(storyError)
            return false
        } catch {
            setError(.unknownError(error.localizedDescription))
            return false
        }
    }
    
    func canCreateStory(from post: Post) -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        // Don't allow creating stories from your own posts
        guard post.userId != userId else { return false }
        
        return true
    }
    
    func cleanupExpiredStories() async {
        do {
            try await storyService.cleanupExpiredStories()
            logger.logInfo("Expired stories cleaned up", category: "ViewModel")
        } catch let storyError as StoryError {
            setError(storyError)
        } catch {
            setError(.unknownError(error.localizedDescription))
        }
    }
    
    // MARK: - Private Methods
    private func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    private func setError(_ error: StoryError) {
        self.error = error
        hasError = true
        logger.logError(error, context: "StoryViewModel")
    }
    
    private func clearError() {
        error = nil
        hasError = false
    }
}

// MARK: - Story Preview ViewModel
/// ViewModel for story preview functionality
@MainActor
class StoryPreviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isPosting = false
    @Published var error: StoryError?
    @Published var hasError = false
    @Published var isPosted = false
    
    // MARK: - Private Properties
    private let storyService: StoryServiceProtocol
    private let logger: StoryLoggingProtocol
    
    // MARK: - Initialization
    init(
        storyService: StoryServiceProtocol? = nil,
        logger: StoryLoggingProtocol? = nil
    ) {
        self.storyService = storyService ?? StoryServiceContainer.shared.storyService
        self.logger = logger ?? StoryLogger()
    }
    
    // MARK: - Public Methods
    func postStory(_ post: Post) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            setError(.validationError("User not authenticated"))
            return false
        }
        
        setPosting(true)
        clearError()
        
        do {
            let request = CreateStoryRequest(postId: post.id, userId: userId)
            _ = try await storyService.createStory(request: request)
            
            logger.logInfo("Story posted successfully for post: \(post.id)", category: "PreviewViewModel")
            
            setPosted(true)
            return true
            
        } catch let storyError as StoryError {
            setError(storyError)
            return false
        } catch {
            setError(.unknownError(error.localizedDescription))
            return false
        }
    }
    
    func reset() {
        isPosting = false
        isPosted = false
        clearError()
    }
    
    // MARK: - Private Methods
    private func setPosting(_ posting: Bool) {
        isPosting = posting
    }
    
    private func setPosted(_ posted: Bool) {
        isPosted = posted
    }
    
    private func setError(_ error: StoryError) {
        self.error = error
        hasError = true
        logger.logError(error, context: "StoryPreviewViewModel")
    }
    
    private func clearError() {
        error = nil
        hasError = false
    }
}
