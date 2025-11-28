//
//  StoryService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - CodingUserInfoKey Extension
extension CodingUserInfoKey {
    static let documentReference = CodingUserInfoKey(rawValue: "DocumentRefUserInfoKey")!
}

class StoryService: StoryServiceProtocol {
    private let db = Firestore.firestore()
    private let storiesCollection = "stories"
    
    // MARK: - Dependencies
    private let profileService: ProfileServiceProtocol
    private let postService: PostServiceProtocol
    
    init(profileService: ProfileServiceProtocol, postService: PostServiceProtocol) {
        self.profileService = profileService
        self.postService = postService
    }
    
    // MARK: - Story Creation
    func createStory(request: CreateStoryRequest) async throws -> Story {
        // Check if story already exists for this post and user
        if try await storyExists(for: request.postId, userId: request.userId) {
            throw StoryError.duplicateResource("You have already shared this post to your story")
        }
        
        let story = Story(userId: request.userId, postId: request.postId)
        
        try await db.collection(storiesCollection)
            .document(story.id!)
            .setData(story.toDictionary())
        
        return story
    }
    
    // MARK: - Story Retrieval
    func getStoriesForUser(userId: String) async throws -> [Story] {
        let snapshot = try await db.collection(storiesCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("expiresAt", isGreaterThan: Date())
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Story(from: document)
        }
    }
    
    func getStoriesFromFollowing(userId: String) async throws -> [Story] {
        // Get following list
        let followingProfiles = try await profileService.getUserProfiles(userIds: [userId]) // This would need to be implemented properly
        // For now, return empty array as this needs proper following relationship implementation
        return []
    }
    
    func getStoryItemsForUser(userId: String) async throws -> [StoryItem] {
        let stories = try await getStoriesForUser(userId: userId)
        return try await enrichStories(stories, for: userId)
    }
    
    func getStoryItemsFromFollowing(userId: String) async throws -> [StoryItem] {
        let stories = try await getStoriesFromFollowing(userId: userId)
        return try await enrichStories(stories, for: userId)
    }
    
    // MARK: - Story Viewing
    func markStoryAsViewed(storyId: String, userId: String) async throws {
        let storyRef = db.collection(storiesCollection).document(storyId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let storyDocument: DocumentSnapshot
                storyDocument = try transaction.getDocument(storyRef)
                
                guard var story = try? Story(from: storyDocument) else {
                    throw StoryError.resourceNotFound("Story not found")
                }
                
                story.markAsViewed(by: userId)
                
                transaction.updateData([
                    "viewers": story.viewers,
                    "viewCount": story.viewCount
                ], forDocument: storyRef)
                
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    // MARK: - Story Management
    func deleteStory(storyId: String) async throws {
        try await db.collection(storiesCollection).document(storyId).delete()
    }
    
    func cleanupExpiredStories() async throws {
        let expiredStories = try await db.collection(storiesCollection)
            .whereField("expiresAt", isLessThan: Date())
            .getDocuments()
        
        let batch = db.batch()
        expiredStories.documents.forEach { document in
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Story Status
    func storyExists(for postId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection(storiesCollection)
            .whereField("postId", isEqualTo: postId)
            .whereField("userId", isEqualTo: userId)
            .whereField("expiresAt", isGreaterThan: Date())
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // MARK: - Private Helpers
    private func enrichStories(_ stories: [Story], for userId: String) async throws -> [StoryItem] {
        var storyItems: [StoryItem] = []
        
        for story in stories {
            // Get post data - need to implement this properly
            // For now, skip posts that can't be retrieved
            guard let post = try? await getPostById(story.postId) else {
                continue
            }
            
            // Get user data
            guard let user = try await profileService.getUserProfile(userId: story.userId) else {
                continue
            }
            
            let storyItem = StoryItem(
                id: story.id!,
                story: story,
                post: post,
                user: user
            )
            
            storyItems.append(storyItem)
        }
        
        return storyItems
    }
    
    private func getPostById(_ postId: String) async throws -> Post? {
        // This is a temporary implementation - should use PostService properly
        let db = Firestore.firestore()
        let docRef = db.collection("posts").document(postId)
        let document = try await docRef.getDocument()
        
        return try? document.data(as: Post.self)
    }
}

// MARK: - Story Extensions
extension Story {
    init?(from document: DocumentSnapshot) throws {
        guard let data = document.data() else { return nil }
        
        let decoder = Firestore.Decoder()
        decoder.userInfo[.documentReference] = document.reference
        self = try decoder.decode(Story.self, from: data)
        self.id = document.documentID
    }
    
    func toDictionary() -> [String: Any] {
        do {
            return try Firestore.Encoder().encode(self)
        } catch {
            print("Error encoding story: \(error)")
            return [:]
        }
    }
}
