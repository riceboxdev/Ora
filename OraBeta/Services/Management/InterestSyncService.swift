import Foundation
import FirebaseFirestore

/// Service to synchronize interest post counts with actual post data
/// This recalculates postCount for all interests based on actual posts in Firestore
class InterestSyncService {
    static let shared = InterestSyncService()
    private let db = Firestore.firestore()
    
    struct SyncResult {
        let processed: Int
        let updated: Int
        let errors: [(interestId: String, error: String)]
        let details: [(id: String, name: String, oldCount: Int, newCount: Int, updated: Bool)]
    }
    
    /// Recalculate and update post counts for all interests
    /// - Returns: SyncResult with details of the synchronization
    func syncAllInterestPostCounts() async throws -> SyncResult {
        var processed = 0
        var updated = 0
        var errors: [(String, String)] = []
        var details: [(String, String, Int, Int, Bool)] = []
        
        Logger.log("🔄 Starting interest post count synchronization...", service: "InterestSync")
        
        // Fetch all interests
        let interestsSnapshot = try await db.collection("interests").getDocuments()
        let interests = interestsSnapshot.documents.map { doc -> (id: String, data: [String: Any]) in
            return (id: doc.documentID, data: doc.data())
        }
        
        Logger.log("📊 Found \(interests.count) interests to process", service: "InterestSync")
        
        // Fetch all active posts
        let postsSnapshot = try await db.collection("posts")
            .whereField("isDeleted", isEqualTo: false)
            .getDocuments()
        
        let posts = postsSnapshot.documents.map { doc -> [String: Any] in
            var data = doc.data()
            data["id"] = doc.documentID
            return data
        }
        
        Logger.log("📝 Found \(posts.count) active posts", service: "InterestSync")
        
        // Process each interest
        for interest in interests {
            do {
                let interestId = interest.id
                let interestData = interest.data
                let oldCount = interestData["postCount"] as? Int ?? 0
                let displayName = interestData["displayName"] as? String ?? interestData["name"] as? String ?? interestId
                
                // Count posts that have this interest ID
                let interestPosts = posts.filter { post in
                    guard let interestIds = post["interestIds"] as? [String] else { return false }
                    return interestIds.contains(interestId)
                }
                
                let actualCount = interestPosts.count
                
                // Find most recent post for this interest
                var lastPostAt: Timestamp?
                if !interestPosts.isEmpty {
                    let sortedPosts = interestPosts.sorted { post1, post2 in
                        guard let t1 = post1["createdAt"] as? Timestamp,
                              let t2 = post2["createdAt"] as? Timestamp else {
                            return false
                        }
                        return t1.seconds > t2.seconds
                    }
                    lastPostAt = sortedPosts.first?["createdAt"] as? Timestamp
                }
                
                // Update interest if count changed
                if oldCount != actualCount {
                    var updateData: [String: Any] = [
                        "postCount": actualCount,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                    
                    if let lastPostAt = lastPostAt {
                        updateData["lastPostAt"] = lastPostAt
                    }
                    
                    try await db.collection("interests").document(interestId).updateData(updateData)
                    updated += 1
                    
                    Logger.log("✅ Updated \(interestId): \(oldCount) → \(actualCount)", service: "InterestSync")
                    
                    details.append((interestId, displayName, oldCount, actualCount, true))
                } else {
                    details.append((interestId, displayName, oldCount, actualCount, false))
                }
                
                processed += 1
            } catch {
                Logger.error("❌ Error processing interest \(interest.id): \(error.localizedDescription)", service: "InterestSync")
                errors.append((interest.id, error.localizedDescription))
            }
        }
        
        Logger.log("✅ Sync complete: \(updated)/\(processed) interests updated", service: "InterestSync")
        
        return SyncResult(
            processed: processed,
            updated: updated,
            errors: errors,
            details: details
        )
    }
    
    /// Sync a single interest's post count
    /// - Parameter interestId: The ID of the interest to sync
    /// - Returns: Tuple of (oldCount, newCount)
    func syncInterestPostCount(interestId: String) async throws -> (oldCount: Int, newCount: Int) {
        Logger.log("🔄 Syncing post count for interest: \(interestId)", service: "InterestSync")
        
        // Get the interest
        let interestDoc = try await db.collection("interests").document(interestId).getDocument()
        guard interestDoc.exists else {
            throw NSError(domain: "InterestSync", code: 404, userInfo: [NSLocalizedDescriptionKey: "Interest not found"])
        }
        
        let interestData = interestDoc.data() ?? [:]
        let oldCount = interestData["postCount"] as? Int ?? 0
        
        // Count posts with this interest ID
        let postsSnapshot = try await db.collection("posts")
            .whereField("isDeleted", isEqualTo: false)
            .whereField("interestIds", arrayContains: interestId)
            .getDocuments()
        
        let actualCount = postsSnapshot.documents.count
        
        // Update if changed
        if oldCount != actualCount {
            // Find most recent post
            var lastPostAt: Timestamp?
            if !postsSnapshot.documents.isEmpty {
                let sortedDocs = postsSnapshot.documents.sorted { doc1, doc2 in
                    guard let t1 = doc1.data()["createdAt"] as? Timestamp,
                          let t2 = doc2.data()["createdAt"] as? Timestamp else {
                        return false
                    }
                    return t1.seconds > t2.seconds
                }
                lastPostAt = sortedDocs.first?.data()["createdAt"] as? Timestamp
            }
            
            var updateData: [String: Any] = [
                "postCount": actualCount,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            if let lastPostAt = lastPostAt {
                updateData["lastPostAt"] = lastPostAt
            }
            
            try await db.collection("interests").document(interestId).updateData(updateData)
            Logger.log("✅ Updated \(interestId): \(oldCount) → \(actualCount)", service: "InterestSync")
        }
        
        return (oldCount: oldCount, newCount: actualCount)
    }
}
