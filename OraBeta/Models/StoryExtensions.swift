//
//  StoryExtensions.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation

// MARK: - StoryItem Extensions for Previews
extension StoryItem {
    static var sampleStory: StoryItem {
        var story = Story(userId: "user1", postId: "post1")
        story.id = "preview_story_1" // Add this line to set a default ID
        let post = Post.samplePost
        let user = FakeUsers.users[0]
        
        return StoryItem(
            id: story.id!,
            story: story,
            post: post,
            user: user
        )
    }
    
    static var sampleStory2: StoryItem {
        var story = Story(userId: "user2", postId: "post2")
        story.id = "preview_story_2"
        let post = Post(
            activityId: "sample_post_2",
            userId: "user2",
            username: "jordan",
            imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762805411/users/qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1/zm899dpw8praxbm8unbn.jpg",
            caption: "Another angle from the same adventure."
        )
        let user = FakeUsers.users.count > 1 ? FakeUsers.users[1] : FakeUsers.users[0]
        
        return StoryItem(
            id: story.id!,
            story: story,
            post: post,
            user: user
        )
    }
}

// MARK: - Post Extensions for Previews
extension Post {
    static var samplePost: Post {
        Post(
            activityId: "sample_post_1",
            userId: "user1",
            username: "alexj",
            imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762830367/users/ChXrUkIGqsS1TMVi6avPKAhIlxn1/jxotu1llhwxn2swukk1l.jpg",
            caption: "Check out this amazing view! 🌅"
        )
    }
}
