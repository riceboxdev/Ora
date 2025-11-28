//
//  FeedService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedService: FeedServiceProtocol {
    private let db = Firestore.firestore()
    private let profileService: ProfileService
    
    init(profileService: ProfileService? = nil) {
        self.profileService = profileService ?? ProfileService()
    }
    
    /// Get discover feed with ranking strategy
    /// - Parameters:
    ///   - userId: Current user ID (for personalized ranking if needed)
    ///   - limit: Maximum number of posts to return
    ///   - strategy: Ranking strategy to use (only applied on initial load or refresh, not on pagination)
    ///   - lastDocument: Last document for pagination (optional)
    ///   - applyRanking: Whether to apply ranking strategy (default: true, set to false for pagination to maintain order)
    /// - Returns: Array of posts (ranked if applyRanking is true, otherwise in Firestore order)
    func getDiscoverFeed(
        userId: String? = nil,
        limit: Int = 20,
        strategy: RankingStrategy = HybridStrategy(recencyWeight: 0.3, popularityWeight: 0.7),
        lastDocument: QueryDocumentSnapshot? = nil,
        applyRanking: Bool = true
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?) {
        Logger.info("Fetching discover feed", service: "FeedService")
        Logger.debug("Strategy: \(strategy.name)", service: "FeedService")
        Logger.debug("Limit: \(limit)", service: "FeedService")
        Logger.debug("Apply ranking: \(applyRanking)", service: "FeedService")
        
        // Build query - start with all posts ordered by createdAt
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
        
        // Apply pagination if lastDocument is provided
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        // Limit results
        query = query.limit(to: limit)
        
        // Fetch posts
        let snapshot = try await query.getDocuments()
        Logger.info("Fetched \(snapshot.documents.count) posts from Firestore", service: "FeedService")
        
        // Extract unique user IDs from documents
        var userIds: Set<String> = []
        for document in snapshot.documents {
            let data = document.data()
            if let userId = data["userId"] as? String {
                userIds.insert(userId)
            }
        }
        
        // Batch fetch profiles for all unique user IDs
        let profiles: [String: UserProfile]
        if !userIds.isEmpty {
            do {
                profiles = try await profileService.getUserProfiles(userIds: Array(userIds))
                Logger.info("Batch fetched \(profiles.count) profiles for \(userIds.count) unique users", service: "FeedService")
            } catch {
                Logger.warning("Failed to batch fetch profiles: \(error.localizedDescription)", service: "FeedService")
                profiles = [:]
            }
        } else {
            profiles = [:]
        }
        
        // Convert Firestore documents to Post objects (using batched profiles)
        // Note: Posts from Firestore already include engagement metrics (likeCount, commentCount, etc.)
        // We use these metrics directly without re-fetching to prevent re-ranking during scrolling
        var posts: [Post] = []
        for document in snapshot.documents {
            let data = document.data()
            if let post = await Post.from(firestoreData: data, documentId: document.documentID, profiles: profiles) {
                posts.append(post)
            }
        }
        
        // Note: We don't reload engagement metrics here to prevent re-ranking
        // Posts from Firestore already have metrics at the time of fetch
        // Metrics will be updated on the next explicit refresh (pull to refresh)
        // This ensures the feed order remains stable during scrolling
        
        // Analyze posts without semantic labels in background (non-blocking)
        Task {
            await PostAnalysisService.shared.analyzePostsInBackground(posts: posts, batchSize: 3)
        }
        
        // Apply ranking strategy only if requested (typically on initial load or refresh)
        // For pagination, maintain Firestore order to prevent re-ranking existing posts
        let finalPosts: [Post]
        if applyRanking {
            finalPosts = strategy.rank(posts: posts, for: userId)
            Logger.info("Applied ranking strategy - posts reordered", service: "FeedService")
        } else {
            // For pagination, maintain the order from Firestore (createdAt descending)
            // This ensures new posts are appended without affecting existing order
            finalPosts = posts
            Logger.info("Skipped ranking - maintaining Firestore order for pagination", service: "FeedService")
        }
        
        // Get last document for pagination
        let lastDoc = snapshot.documents.last
        
        Logger.info("Returning \(finalPosts.count) posts", service: "FeedService")
        Logger.debug("First post ID: \(finalPosts.first?.id ?? "none")", service: "FeedService")
        Logger.debug("Last post ID: \(finalPosts.last?.id ?? "none")", service: "FeedService")
        
        return (finalPosts, lastDoc)
    }
    
    // Note: Removed loadEngagementMetrics method
    // We now use metrics directly from Post objects loaded from Firestore
    // This prevents re-ranking during scrolling and ensures feed stability
    // Metrics are only updated when the feed is explicitly refreshed
}

