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
        
        // Process each interest using direct Firestore queries
        for interest in interests {
            do {
                let interestId = interest.id
                let interestData = interest.data
                let oldCount = interestData["postCount"] as? Int ?? 0
                let displayName = interestData["displayName"] as? String ?? interestData["name"] as? String ?? interestId
                
                // IMPROVED: Query Firestore directly for this interest's posts
                // This is much more efficient than loading all posts
                let postsQuery = db.collection("posts")
                    .whereField("isDeleted", isEqualTo: false)
                    .whereField("interestIds", arrayContains: interestId)
                
                let postsSnapshot = try await postsQuery.getDocuments()
                let actualCount = postsSnapshot.documents.count
                
                Logger.log("Interest '\(interestId)': oldCount=\(oldCount), actualCount=\(actualCount)", service: "InterestSync")
                
                // Find most recent post for this interest
                var lastPostAt: Timestamp?
                if !postsSnapshot.documents.isEmpty {
                    // Sort by createdAt to find most recent
                    let sortedDocs = postsSnapshot.documents.sorted { doc1, doc2 in
                        guard let t1 = doc1.data()["createdAt"] as? Timestamp,
                              let t2 = doc2.data()["createdAt"] as? Timestamp else {
                            return false
                        }
                        return t1.seconds > t2.seconds
                    }
                    lastPostAt = sortedDocs.first?.data()["createdAt"] as? Timestamp
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
                    Logger.log("➡️ Unchanged \(interestId): \(actualCount)", service: "InterestSync")
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
