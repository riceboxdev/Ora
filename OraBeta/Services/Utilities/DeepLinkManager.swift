//
//  DeepLinkManager.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/29/25.
//

import Foundation
import SwiftUI
import Combine

/// Deep link types supported by the app
enum DeepLinkDestination: Equatable {
    case post(postId: String, openComments: Bool = false)
    case profile(userId: String)
    case comment(postId: String, commentId: String)
    
    var description: String {
        switch self {
        case .post(let postId, let openComments):
            return "post/\(postId)\(openComments ? "/comments" : "")"
        case .profile(let userId):
            return "profile/\(userId)"
        case .comment(let postId, let commentId):
            return "comment/\(postId)/\(commentId)"
        }
    }
}

/// Manager for handling deep links throughout the app
@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    /// Published destination that views can observe
    @Published var pendingDestination: DeepLinkDestination?
    
    private init() {}
    
    /// Parse a deep link string into a destination
    /// - Parameter deepLink: String in format "post/123", "profile/abc", "comment/123/456"
    /// - Returns: DeepLinkDestination if valid, nil otherwise
    func parseDeepLink(_ deepLink: String) -> DeepLinkDestination? {
        let components = deepLink.split(separator: "/").map(String.init)
        
        guard !components.isEmpty else { return nil }
        
        switch components[0] {
        case "post":
            guard components.count >= 2 else { return nil }
            let postId = components[1]
            let openComments = components.count >= 3 && components[2] == "comments"
            return .post(postId: postId, openComments: openComments)
            
        case "profile":
            guard components.count >= 2 else { return nil }
            return .profile(userId: components[1])
            
        case "comment":
            guard components.count >= 3 else { return nil }
            return .comment(postId: components[1], commentId: components[2])
            
        default:
            Logger.warning("Unknown deep link type: \(components[0])", service: "DeepLinkManager")
            return nil
        }
    }
    
    /// Handle a deep link by setting the pending destination
    /// This will be observed by ContentView to trigger navigation
    func handleDeepLink(_ deepLink: String) {
        Logger.info("Handling deep link: \(deepLink)", service: "DeepLinkManager")
        
        guard let destination = parseDeepLink(deepLink) else {
            Logger.error("Failed to parse deep link: \(deepLink)", service: "DeepLinkManager")
            return
        }
        
        pendingDestination = destination
        Logger.info("Set pending destination: \(destination.description)", service: "DeepLinkManager")
    }
    
    /// Clear the pending destination after navigation is complete
    func clearPendingDestination() {
        pendingDestination = nil
    }
    
    /// Generate a deep link string for a notification
    static func generateDeepLink(for notification: Notification) -> String {
        switch notification.type {
        case .like:
            return "post/\(notification.targetId)"
            
        case .comment:
            return "post/\(notification.targetId)/comments"
            
        case .follow:
            // Use the first actor's ID for follow notifications
            if let firstActorId = notification.actors.first?.id {
                return "profile/\(firstActorId)"
            }
            return ""
            
        case .mention:
            // Mentions are in comments, open the post with comments
            return "post/\(notification.targetId)/comments"
        }
    }
}
