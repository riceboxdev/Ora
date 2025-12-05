//
//  InterestPreviewService.swift
//  OraBeta
//
//  Service to fetch preview posts for trending interests
//  Similar to TopicPreviewService but queries by interestIds
//

import Foundation
import FirebaseFirestore

@MainActor
class InterestPreviewService {
    private let db = Firestore.firestore()
    
    // MARK: - Public Methods
    
    /// Get preview posts for multiple interests
    /// Uses Firestore queries to find posts containing each interest ID
    ///
    /// - Parameters:
    ///   - interests: Array of trending interests
    ///   - limitPerInterest: Max posts per interest
    /// - Returns: Dictionary mapping interest ID to preview posts
    func getInterestPreviews(
        interests: [TrendingInterest],
        limitPerInterest: Int = 3
    ) async -> [String: [Post]] {
        var previews: [String: [Post]] = [:]
        
        // Fetch previews for each interest concurrently
        await withTaskGroup(of: (String, [Post]).self) { group in
            for interest in interests {
                group.addTask {
                    let posts = await self.getPreviewForInterest(
                        interest: interest,
                        limit: limitPerInterest
                    )
                    return (interest.id, posts)
                }
            }
            
            for await (interestId, posts) in group {
                previews[interestId] = posts
            }
        }
        
        return previews
    }
    
    // MARK: - Private Methods
    
    /// Get preview posts for a single interest
    ///
    /// - Parameters:
    ///   - interest: Trending interest
    ///   - limit: Max posts to return
    /// - Returns: Array of preview posts
    private func getPreviewForInterest(
        interest: TrendingInterest,
        limit: Int
    ) async -> [Post] {
        do {
            // Query posts where interestIds array contains this interest ID
            let query = db.collection("posts")
                .whereField("interestIds", arrayContains: interest.id)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            
            // Convert documents to Post objects
            var posts: [Post] = []
            for document in snapshot.documents {
                if let post = await Post.from(
                    firestoreData: document.data(),
                    documentId: document.documentID,
                    profiles: [:]
                ) {
                    posts.append(post)
                }
            }
            
            print("✅ InterestPreviewService: Loaded \(posts.count) preview posts for interest '\(interest.name)'")
            return posts
        } catch {
            print("❌ InterestPreviewService: Failed to load previews for interest '\(interest.name)': \(error.localizedDescription)")
            return []
        }
    }
}
