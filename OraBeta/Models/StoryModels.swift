//
//  StoryModels.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Core Story Model
struct Story: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    public let userId: String
    let postId: String // Reference to the original post being shared
    let createdAt: Date
    let expiresAt: Date // Stories typically expire after 24 hours
    var viewCount: Int
    var viewers: [String] // Array of user IDs who viewed this story
    
    init(userId: String, postId: String, expiresAt: Date = Date().addingTimeInterval(24 * 60 * 60)) {
        self.userId = userId
        self.postId = postId
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.viewCount = 0
        self.viewers = []
    }
    
    // Check if story has expired
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    // Check if a user has viewed this story
    func hasViewed(by userId: String) -> Bool {
        viewers.contains(userId)
    }
    
    // Mark story as viewed by a user
    mutating func markAsViewed(by userId: String) {
        if !viewers.contains(userId) {
            viewers.append(userId)
            viewCount += 1
        }
    }
    
    // Equatable implementation
    static func == (lhs: Story, rhs: Story) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Story with Post Data (for UI)
struct StoryItem: Identifiable, Equatable {
    let id: String
    let story: Story
    let post: Post
    let user: UserProfile
    
    // Computed properties for UI
    var isViewed: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return story.hasViewed(by: currentUserId)
    }
    
    var timeRemaining: TimeInterval {
        max(0, story.expiresAt.timeIntervalSinceNow)
    }
    
    init(id: String, story: Story, post: Post, user: UserProfile) {
        self.id = id
        self.story = story
        self.post = post
        self.user = user
    }
    
    static func == (lhs: StoryItem, rhs: StoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Story Creation Request
struct CreateStoryRequest {
    let postId: String
    let userId: String
    
    init(postId: String, userId: String) {
        self.postId = postId
        self.userId = userId
    }
}

// MARK: - Story View Event
struct StoryViewEvent {
    let storyId: String
    let userId: String
    let viewedAt: Date
    
    init(storyId: String, userId: String) {
        self.storyId = storyId
        self.userId = userId
        self.viewedAt = Date()
    }
}
