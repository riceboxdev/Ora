//
//  EnhancedStoryService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class EnhancedStoryService: StoryServiceProtocol {
    private let repository: StoryRepositoryProtocol
    private let profileService: ProfileServiceProtocol
    private let postService: PostServiceProtocol
    
    init(
        configuration: StoryConfiguration = .default,
        repository: StoryRepositoryProtocol? = nil,
        cache: StoryCacheProtocol? = nil,
        analytics: StoryAnalyticsProtocol? = nil,
        logger: StoryLoggingProtocol? = nil,
        profileService: ProfileServiceProtocol,
        postService: PostServiceProtocol
    ) {
        self.repository = repository ?? StoryRepository(logger: logger ?? StoryLogger(configuration: configuration))
        self.profileService = profileService
        self.postService = postService
    }
    
    // MARK: - Story Creation
    func createStory(request: CreateStoryRequest) async throws -> Story {
        print("🔍 EnhancedStoryService.createStory called for post: \(request.postId)")
        
        // Create the story
        let story = Story(userId: request.userId, postId: request.postId)
        let createdStory = try await repository.create(story)
        
        print("✅ Story created successfully: \(createdStory.id ?? "unknown")")
        return createdStory
    }
    
    // MARK: - Story Retrieval
    func getStoriesForUser(userId: String) async throws -> [Story] {
        print("🔍 EnhancedStoryService.getStoriesForUser called for: \(userId)")
        
        do {
            let stories = try await repository.fetchStories(for: userId, limit: 10, after: nil)
            print("🔍 Retrieved \(stories.count) stories from repository")
            return stories
        } catch {
            print("❌ Error in getStoriesForUser: \(error)")
            throw error
        }
    }
    
    func getStoriesFromFollowing(userId: String) async throws -> [Story] {
        print("🔍 EnhancedStoryService.getStoriesFromFollowing called for: \(userId)")
        return []
    }
    
    func getStoryItemsForUser(userId: String) async throws -> [StoryItem] {
        print("🔍 EnhancedStoryService.getStoryItemsForUser called for: \(userId)")
        
        let stories = try await getStoriesForUser(userId: userId)
        print("🔍 Retrieved \(stories.count) stories, now enriching...")
        
        var storyItems: [StoryItem] = []
        
        for story in stories {
            do {
                print("🔍 Enriching story: \(story.id ?? "unknown") for post: \(story.postId) by user: \(story.userId)")
                
                // Get post data directly by ID (the post may belong to a different user than the story owner)
                print("🔍 Fetching post by ID: \(story.postId)")
                let doc = try await Firestore.firestore()
                    .collection("posts")
                    .document(story.postId)
                    .getDocument()
                
                guard doc.exists, let data = doc.data() else {
                    print("❌ Could not find post document with ID: \(story.postId)")
                    continue
                }
                
                guard let post = await Post.from(
                    firestoreData: data,
                    documentId: doc.documentID
                ) else {
                    print("❌ Failed to parse post for ID: \(story.postId)")
                    continue
                }
                
                print("✅ Found post: \(post.id)")
                
                // Get user data
                guard let user = try await profileService.getUserProfile(userId: story.userId) else {
                    print("❌ Could not find user with ID: \(story.userId)")
                    continue
                }
                
                print("✅ Found user: \(user.displayName ?? "unknown")")
                
                let storyItem = StoryItem(
                    id: story.id!,
                    story: story,
                    post: post,
                    user: user
                )
                
                storyItems.append(storyItem)
                print("✅ Successfully enriched story: \(story.id!)")
            } catch {
                print("❌ Error enriching story \(story.id ?? "unknown"): \(error)")
            }
        }
        
        print("🔍 Successfully enriched \(storyItems.count) stories")
        return storyItems
    }
    
    func getStoryItemsFromFollowing(userId: String) async throws -> [StoryItem] {
        return []
    }
    
    // MARK: - Story Viewing
    func markStoryAsViewed(storyId: String, userId: String) async throws {
        print("🔍 Marking story as viewed: \(storyId) by user: \(userId)")
        // Implementation would go here
    }
    
    func deleteStory(storyId: String) async throws {
        print("🔍 Deleting story: \(storyId)")
        try await repository.delete(id: storyId)
    }
    
    func cleanupExpiredStories() async throws {
        print("🔍 Cleaning up expired stories")
        // Implementation would go here
    }
    
    func storyExists(for postId: String, userId: String) async throws -> Bool {
        print("🔍 Checking if story exists for post: \(postId), user: \(userId)")
        
        do {
            let stories = try await repository.fetchStories(for: userId, limit: 100, after: nil)
            let exists = stories.contains { $0.postId == postId }
            print("🔍 Story exists check result: \(exists)")
            return exists
        } catch {
            print("❌ Error checking story existence: \(error)")
            throw error
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
