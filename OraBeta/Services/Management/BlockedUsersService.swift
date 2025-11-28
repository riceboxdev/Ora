//
//  BlockedUsersService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class BlockedUsersService {
    private let db = Firestore.firestore()
    private let blockedUsersCollection = "blocked_users"
    
    /// Block a user
    func blockUser(blockedId: String, reason: String? = nil) async throws {
        guard let blockerId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BlockedUsersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard blockerId != blockedId else {
            throw NSError(domain: "BlockedUsersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot block yourself"])
        }
        
        let documentId = "\(blockerId)_\(blockedId)"
        
        let blockedUser = BlockedUser(
            id: documentId,
            blockerId: blockerId,
            blockedId: blockedId,
            blockedAt: Date(),
            reason: reason
        )
        
        try await db.collection(blockedUsersCollection).document(documentId).setData(from: blockedUser)
        print("✅ BlockedUsersService: Blocked user \(blockedId)")
    }
    
    /// Unblock a user
    func unblockUser(blockedId: String) async throws {
        guard let blockerId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BlockedUsersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let documentId = "\(blockerId)_\(blockedId)"
        try await db.collection(blockedUsersCollection).document(documentId).delete()
        print("✅ BlockedUsersService: Unblocked user \(blockedId)")
    }
    
    /// Get list of blocked users
    func getBlockedUsers() async throws -> [BlockedUser] {
        guard let blockerId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BlockedUsersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let snapshot = try await db.collection(blockedUsersCollection)
            .whereField("blockerId", isEqualTo: blockerId)
            .order(by: "blockedAt", descending: true)
            .getDocuments()
        
        let blockedUsers = try snapshot.documents.map { doc in
            var blockedUser = try doc.data(as: BlockedUser.self)
            blockedUser.id = doc.documentID
            return blockedUser
        }
        
        print("✅ BlockedUsersService: Retrieved \(blockedUsers.count) blocked users")
        return blockedUsers
    }
    
    /// Check if a user is blocked
    func isUserBlocked(blockedId: String) async throws -> Bool {
        guard let blockerId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let documentId = "\(blockerId)_\(blockedId)"
        let doc = try await db.collection(blockedUsersCollection).document(documentId).getDocument()
        return doc.exists
    }
    
    /// Check if current user is blocked by another user
    func isBlockedBy(blockerId: String) async throws -> Bool {
        guard let blockedId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let documentId = "\(blockerId)_\(blockedId)"
        let doc = try await db.collection(blockedUsersCollection).document(documentId).getDocument()
        return doc.exists
    }
}

