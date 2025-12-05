//
//  InterestFollowService.swift
//  OraBeta
//
//  Service to manage user following/unfollowing of interests
//  Stores followed interests in user document
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class InterestFollowService {
    private let db = Firestore.firestore()
    
    static let shared = InterestFollowService()
    
    private init() {}
    
    // MARK: - Follow/Unfollow
    
    /// Follow an interest
    func followInterest(interestId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "InterestFollowService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "followedInterests": FieldValue.arrayUnion([interestId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update interest follower count
        let interestRef = db.collection("interests").document(interestId)
        try await interestRef.updateData([
            "followerCount": FieldValue.increment(Int64(1))
        ])
        
        print("✅ InterestFollowService: Followed interest \(interestId)")
    }
    
    /// Unfollow an interest
    func unfollowInterest(interestId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "InterestFollowService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "followedInterests": FieldValue.arrayRemove([interestId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update interest follower count
        let interestRef = db.collection("interests").document(interestId)
        try await interestRef.updateData([
            "followerCount": FieldValue.increment(Int64(-1))
        ])
        
        print("✅ InterestFollowService: Unfollowed interest \(interestId)")
    }
    
    // MARK: - Check Status
    
    /// Check if user is following an interest
    func isFollowingInterest(interestId: String) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        guard let followedInterests = document.data()?["followedInterests"] as? [String] else {
            return false
        }
        
        return followedInterests.contains(interestId)
    }
    
    // MARK: - Get Followed Interests
    
    /// Get all interest IDs the user is following
    func getFollowedInterests() async throws -> [String] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        return document.data()?["followedInterests"] as? [String] ?? []
    }
    
    /// Get followed interest IDs from a list of trending interests
    /// Returns a Set of IDs for quick lookup
    func getFollowedInterestIds(from interests: [TrendingInterest]) async throws -> Set<String> {
        let followedIds = try await getFollowedInterests()
        let interestIds = Set(interests.map { $0.id })
        return interestIds.intersection(followedIds)
    }
}
