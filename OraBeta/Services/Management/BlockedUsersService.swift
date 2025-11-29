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
    
    // MARK: - Caching
    private var blockedUserIdsCache: Set<String>?
    private var blockedByUserIdsCache: Set<String>?
    private var cacheTimestamp: Date?
    private var cacheTTL: TimeInterval = 300 // 5 minutes
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
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
        
        // Invalidate cache after blocking
        invalidateCache()
    }
    
    /// Unblock a user
    func unblockUser(blockedId: String) async throws {
        guard let blockerId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BlockedUsersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let documentId = "\(blockerId)_\(blockedId)"
        try await db.collection(blockedUsersCollection).document(documentId).delete()
        print("✅ BlockedUsersService: Unblocked user \(blockedId)")
        
        // Invalidate cache after unblocking
        invalidateCache()
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
    
    // MARK: - Caching Methods
    
    /// Get set of user IDs that the current user has blocked (cached)
    func getBlockedUserIds() async throws -> Set<String> {
        // Return empty set if not authenticated
        guard let blockerId = currentUserId else {
            return Set<String>()
        }
        
        // Check cache validity
        if let cache = blockedUserIdsCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cache
        }
        
        // Fetch from Firestore
        let snapshot = try await db.collection(blockedUsersCollection)
            .whereField("blockerId", isEqualTo: blockerId)
            .getDocuments()
        
        let blockedIds = Set(snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            return data["blockedId"] as? String
        })
        
        // Update cache
        blockedUserIdsCache = blockedIds
        cacheTimestamp = Date()
        
        print("✅ BlockedUsersService: Cached \(blockedIds.count) blocked user IDs")
        return blockedIds
    }
    
    /// Get set of user IDs who have blocked the current user (cached, for bidirectional blocking)
    func getBlockedByUserIds() async throws -> Set<String> {
        // Return empty set if not authenticated
        guard let blockedId = currentUserId else {
            return Set<String>()
        }
        
        // Check cache validity
        if let cache = blockedByUserIdsCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cache
        }
        
        // Fetch from Firestore
        let snapshot = try await db.collection(blockedUsersCollection)
            .whereField("blockedId", isEqualTo: blockedId)
            .getDocuments()
        
        let blockerIds = Set(snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            return data["blockerId"] as? String
        })
        
        // Update cache
        blockedByUserIdsCache = blockerIds
        if cacheTimestamp == nil {
            cacheTimestamp = Date()
        }
        
        print("✅ BlockedUsersService: Cached \(blockerIds.count) users who blocked current user")
        return blockerIds
    }
    
    /// Get combined set of all blocked user IDs (both directions) for filtering
    func getAllBlockedUserIds() async throws -> Set<String> {
        // Return empty set if not authenticated
        guard currentUserId != nil else {
            return Set<String>()
        }
        
        // Fetch both sets in parallel
        async let blockedIds = getBlockedUserIds()
        async let blockedByIds = getBlockedByUserIds()
        
        let blocked = try await blockedIds
        let blockedBy = try await blockedByIds
        
        // Combine both sets (bidirectional blocking)
        return blocked.union(blockedBy)
    }
    
    /// Invalidate the cache (call after block/unblock operations)
    func invalidateCache() {
        blockedUserIdsCache = nil
        blockedByUserIdsCache = nil
        cacheTimestamp = nil
        print("🔄 BlockedUsersService: Cache invalidated")
    }
    
    /// Clear cache for a specific user (useful when user logs out)
    func clearCache() {
        invalidateCache()
    }
}

