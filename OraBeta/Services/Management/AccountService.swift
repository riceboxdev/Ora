//
//  AccountService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class AccountService {
    private let db = Firestore.firestore()
    
    /// Delete all user data from Firestore
    /// This should be called before deleting the Firebase Auth account
    func deleteAllUserData(userId: String) async throws {
        print("🗑️ AccountService: Starting deletion of all data for user \(userId)")
        
        // Delete posts
        let postsSnapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in postsSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted \(postsSnapshot.documents.count) posts")
        
        // Delete boards and board_posts
        let boardsSnapshot = try await db.collection("boards")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for boardDoc in boardsSnapshot.documents {
            // Delete all board_posts for this board
            let boardPostsSnapshot = try await db.collection("board_posts")
                .whereField("boardId", isEqualTo: boardDoc.documentID)
                .getDocuments()
            
            for boardPostDoc in boardPostsSnapshot.documents {
                try await boardPostDoc.reference.delete()
            }
            
            // Delete the board
            try await boardDoc.reference.delete()
        }
        print("✅ AccountService: Deleted \(boardsSnapshot.documents.count) boards")
        
        // Delete follows (where user is follower or following)
        let followsAsFollower = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        for doc in followsAsFollower.documents {
            try await doc.reference.delete()
        }
        
        let followsAsFollowing = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        
        for doc in followsAsFollowing.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted follow relationships")
        
        // Delete user profile
        try await db.collection("users").document(userId).delete()
        print("✅ AccountService: Deleted user profile")
        
        // Delete user stats
        try? await db.collection("user_stats").document(userId).delete()
        print("✅ AccountService: Deleted user stats")
        
        // Delete blocked users (where user is blocker or blocked)
        let blockedAsBlocker = try await db.collection("blocked_users")
            .whereField("blockerId", isEqualTo: userId)
            .getDocuments()
        
        for doc in blockedAsBlocker.documents {
            try await doc.reference.delete()
        }
        
        let blockedAsBlocked = try await db.collection("blocked_users")
            .whereField("blockedId", isEqualTo: userId)
            .getDocuments()
        
        for doc in blockedAsBlocked.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted blocked user relationships")
        
        // Delete account settings
        try? await db.collection("account_settings").document(userId).delete()
        print("✅ AccountService: Deleted account settings")
        
        // Delete comments (where user is commenter)
        let commentsSnapshot = try await db.collection("comments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in commentsSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted \(commentsSnapshot.documents.count) comments")
        
        // Delete likes (where user is liker)
        let likesSnapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in likesSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted \(likesSnapshot.documents.count) likes")
        
        // Delete notifications (where user is recipient)
        let notificationsSnapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in notificationsSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted \(notificationsSnapshot.documents.count) notifications")
        
        // Delete saves (where user is saver)
        let savesSnapshot = try await db.collection("saves")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in savesSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ AccountService: Deleted \(savesSnapshot.documents.count) saves")
        
        print("✅ AccountService: Completed deletion of all data for user \(userId)")
    }
    
    /// Export all user data as JSON
    func exportUserData(userId: String) async throws -> [String: Any] {
        print("📦 AccountService: Exporting data for user \(userId)")
        
        var exportData: [String: Any] = [:]
        
        // Export profile
        if let profileDoc = try? await db.collection("users").document(userId).getDocument(),
           profileDoc.exists,
           let profileData = profileDoc.data() {
            exportData["profile"] = profileData
        }
        
        // Export posts
        let postsSnapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        exportData["posts"] = postsSnapshot.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Export boards
        let boardsSnapshot = try await db.collection("boards")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        exportData["boards"] = boardsSnapshot.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Export follows
        let followsAsFollower = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        let followsAsFollowing = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        
        exportData["following"] = followsAsFollower.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        exportData["followers"] = followsAsFollowing.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Export blocked users
        let blockedSnapshot = try await db.collection("blocked_users")
            .whereField("blockerId", isEqualTo: userId)
            .getDocuments()
        
        exportData["blockedUsers"] = blockedSnapshot.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Export account settings
        if let settingsDoc = try? await db.collection("account_settings").document(userId).getDocument(),
           settingsDoc.exists,
           let settingsData = settingsDoc.data() {
            exportData["accountSettings"] = settingsData
        }
        
        // Export comments
        let commentsSnapshot = try await db.collection("comments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        exportData["comments"] = commentsSnapshot.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Export likes
        let likesSnapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        exportData["likes"] = likesSnapshot.documents.map { doc in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        // Add metadata
        exportData["exportMetadata"] = [
            "exportedAt": Timestamp(date: Date()),
            "userId": userId,
            "version": "1.0"
        ]
        
        // Sanitize data for JSON export (convert Timestamps to Strings)
        let sanitizedAny = sanitizeForJSON(exportData)
        let sanitizedData = sanitizedAny as? [String: Any] ?? exportData
        
        print("✅ AccountService: Exported data for user \(userId)")
        return sanitizedData
    }
    
    /// Recursively sanitize data for JSON serialization
    /// Converts Firestore Timestamps to ISO8601 strings
    private func sanitizeForJSON(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        } else if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        } else if let dict = value as? [String: Any] {
            var newDict: [String: Any] = [:]
            for (key, val) in dict {
                newDict[key] = sanitizeForJSON(val)
            }
            return newDict
        } else if let array = value as? [Any] {
            return array.map { sanitizeForJSON($0) }
        } else {
            return value
        }
    }
    
    /// Convenience overload: sanitize a dictionary and return a dictionary
    private func sanitizeForJSON(_ dict: [String: Any]) -> [String: Any] {
        var newDict: [String: Any] = [:]
        for (key, val) in dict {
            newDict[key] = sanitizeForJSON(val)
        }
        return newDict
    }
}

