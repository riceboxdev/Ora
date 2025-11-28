//
//  StoriesRowViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class StoriesRowViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var storyItems: [StoryItem] = []
    @Published var currentUserStory: StoryItem?
    @Published var currentUserStoryItems: [StoryItem]?
    @Published var error: String?
    
    private let storyService: StoryServiceProtocol
    private let profileService: ProfileServiceProtocol
    
    init(storyService: StoryServiceProtocol? = nil, profileService: ProfileServiceProtocol? = nil) {
        self.storyService = storyService ?? StoryServiceContainer.shared.storyService
        self.profileService = profileService ?? DIContainer.shared.profileService
    }
    
    func loadStories() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load current user's stories (all of them)
            let userStories = try await storyService.getStoryItemsForUser(userId: currentUserId)
            currentUserStory = userStories.first
            currentUserStoryItems = userStories.isEmpty ? nil : userStories
            
            // Load stories from following
            let followingStories = try await storyService.getStoryItemsFromFollowing(userId: currentUserId)
            storyItems = followingStories
            
            // Cleanup expired stories in background
            Task {
                try? await storyService.cleanupExpiredStories()
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshStories() async {
        await loadStories()
    }
}
