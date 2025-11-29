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
    private let blockedUsersService: BlockedUsersService
    
    init(profileService: ProfileService? = nil, blockedUsersService: BlockedUsersService? = nil) {
        self.profileService = profileService ?? ProfileService()
        self.blockedUsersService = blockedUsersService ?? BlockedUsersService()
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
        
        // Filter out posts from blocked users (bidirectional blocking)
        let filteredPosts: [Post]
        do {
            let blockedUserIds = try await blockedUsersService.getAllBlockedUserIds()
            let beforeCount = posts.count
            filteredPosts = posts.filter { post in
                !blockedUserIds.contains(post.userId)
            }
            let filteredCount = beforeCount - filteredPosts.count
            if filteredCount > 0 {
                Logger.info("Filtered out \(filteredCount) post(s) from blocked users", service: "FeedService")
            }
        } catch {
            Logger.warning("Failed to get blocked users, showing all posts: \(error.localizedDescription)", service: "FeedService")
            filteredPosts = posts
        }
        
        // Note: We don't reload engagement metrics here to prevent re-ranking
        // Posts from Firestore already have metrics at the time of fetch
        // Metrics will be updated on the next explicit refresh (pull to refresh)
        // This ensures the feed order remains stable during scrolling
        
        // Analyze posts without semantic labels in background (non-blocking)
        Task {
            await PostAnalysisService.shared.analyzePostsInBackground(posts: filteredPosts, batchSize: 3)
        }
        
        // Apply ranking strategy only if requested (typically on initial load or refresh)
        // For pagination, maintain Firestore order to prevent re-ranking existing posts
        let finalPosts: [Post]
        if applyRanking {
            finalPosts = strategy.rank(posts: filteredPosts, for: userId)
            Logger.info("Applied ranking strategy - posts reordered", service: "FeedService")
        } else {
            // For pagination, maintain the order from Firestore (createdAt descending)
            // This ensures new posts are appended without affecting existing order
            finalPosts = filteredPosts
            Logger.info("Skipped ranking - maintaining Firestore order for pagination", service: "FeedService")
        }
        
        // Get last document for pagination
        let lastDoc = snapshot.documents.last
        
        Logger.info("Returning \(finalPosts.count) posts", service: "FeedService")
        Logger.debug("First post ID: \(finalPosts.first?.id ?? "none")", service: "FeedService")
        Logger.debug("Last post ID: \(finalPosts.last?.id ?? "none")", service: "FeedService")
        
        return (finalPosts, lastDoc)
    }
    
    /// Get home feed with posts from followed users and topics
    /// - Parameters:
    ///   - userId: Current user ID (required)
    ///   - limit: Maximum number of posts to return
    ///   - lastDocument: Last document for pagination (optional)
    /// - Returns: Array of posts, last document for pagination, and whether user has follows
    func getHomeFeed(
        userId: String,
        limit: Int = 20,
        lastDocument: QueryDocumentSnapshot? = nil
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?, hasFollows: Bool) {
        Logger.info("Fetching home feed", service: "FeedService")
        Logger.debug("User ID: \(userId)", service: "FeedService")
        Logger.debug("Limit: \(limit)", service: "FeedService")
        
        // Fetch followed user IDs
        let followedUserIdsQuery = db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
        
        let followedUsersSnapshot = try await followedUserIdsQuery.getDocuments()
        let followedUserIds = Set(followedUsersSnapshot.documents.compactMap { doc in
            doc.data()["followingId"] as? String
        })
        
        Logger.info("Found \(followedUserIds.count) followed users", service: "FeedService")
        
        // Fetch followed topics
        let topicFollowService = TopicFollowService.shared
        let followedTopics = try await topicFollowService.getFollowedTopics()
        let followedTopicNamesLowercased = Set(followedTopics.map { $0.name.lowercased() })
        
        Logger.info("Found \(followedTopics.count) followed topics", service: "FeedService")
        
        // Check if user has any follows
        let hasFollows = !followedUserIds.isEmpty || !followedTopics.isEmpty
        
        // If no follows, return empty array
        guard hasFollows else {
            Logger.info("User has no follows - returning empty home feed", service: "FeedService")
            return ([], nil, false)
        }
        
        // Collect all posts from both sources
        var allPostDocuments: [(document: QueryDocumentSnapshot, data: [String: Any])] = []
        
        // Query posts from followed users (batch in groups of 10 due to Firestore 'in' limit)
        if !followedUserIds.isEmpty {
            let userIdArray = Array(followedUserIds)
            let batchSize = 10
            
            for i in stride(from: 0, to: userIdArray.count, by: batchSize) {
                let batch = Array(userIdArray[i..<min(i + batchSize, userIdArray.count)])
                
                var userQuery: Query = db.collection("posts")
                    .whereField("userId", in: batch)
                    .order(by: "createdAt", descending: true)
                
                // Apply pagination only to first batch
                if i == 0, let lastDocument = lastDocument {
                    userQuery = userQuery.start(afterDocument: lastDocument)
                }
                
                // Fetch more than limit to account for deduplication
                userQuery = userQuery.limit(to: limit * 2)
                
                let userSnapshot = try await userQuery.getDocuments()
                
                for document in userSnapshot.documents {
                    allPostDocuments.append((document: document, data: document.data()))
                }
            }
        }
        
        // Query posts with followed topics
        // Note: We'll filter by topic names in memory for case-insensitive matching
        if !followedTopics.isEmpty {
            // Get all unique topic names (original case) for Firestore query
            // We'll use arrayContainsAny with original topic names, then filter in memory
            let topicNamesForQuery = Array(followedTopics.map { $0.name }.prefix(10)) // Firestore limit
            
            var topicQuery: Query = db.collection("posts")
                .whereField("tags", arrayContainsAny: topicNamesForQuery)
                .order(by: "createdAt", descending: true)
            
            // Apply pagination if provided
            if let lastDocument = lastDocument {
                topicQuery = topicQuery.start(afterDocument: lastDocument)
            }
            
            // Fetch more than limit to account for deduplication
            topicQuery = topicQuery.limit(to: limit * 2)
            
            let topicSnapshot = try await topicQuery.getDocuments()
            
            for document in topicSnapshot.documents {
                let data = document.data()
                // Filter in memory for case-insensitive topic matching
                if let tags = data["tags"] as? [String] {
                    let tagsLowercased = Set(tags.map { $0.lowercased() })
                    if !tagsLowercased.isDisjoint(with: followedTopicNamesLowercased) {
                        allPostDocuments.append((document: document, data: data))
                    }
                }
            }
        }
        
        // Deduplicate by document ID
        var uniquePosts: [String: (document: QueryDocumentSnapshot, data: [String: Any])] = [:]
        for item in allPostDocuments {
            if uniquePosts[item.document.documentID] == nil {
                uniquePosts[item.document.documentID] = item
            }
        }
        
        // Sort by createdAt descending
        let sortedPosts = uniquePosts.values.sorted { doc1, doc2 in
            let date1 = (doc1.data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = (doc2.data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 > date2
        }
        
        // Limit to requested amount
        let limitedPosts = Array(sortedPosts.prefix(limit))
        
        // Extract unique user IDs and batch fetch profiles
        var userIds: Set<String> = []
        for item in limitedPosts {
            if let userId = item.data["userId"] as? String {
                userIds.insert(userId)
            }
        }
        
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
        
        // Convert to Post objects
        var posts: [Post] = []
        for item in limitedPosts {
            if let post = await Post.from(firestoreData: item.data, documentId: item.document.documentID, profiles: profiles) {
                posts.append(post)
            }
        }
        
        // Filter out posts from blocked users
        let filteredPosts: [Post]
        do {
            let blockedUserIds = try await blockedUsersService.getAllBlockedUserIds()
            let beforeCount = posts.count
            filteredPosts = posts.filter { post in
                !blockedUserIds.contains(post.userId)
            }
            let filteredCount = beforeCount - filteredPosts.count
            if filteredCount > 0 {
                Logger.info("Filtered out \(filteredCount) post(s) from blocked users", service: "FeedService")
            }
        } catch {
            Logger.warning("Failed to get blocked users, showing all posts: \(error.localizedDescription)", service: "FeedService")
            filteredPosts = posts
        }
        
        // Analyze posts without semantic labels in background (non-blocking)
        Task {
            await PostAnalysisService.shared.analyzePostsInBackground(posts: filteredPosts, batchSize: 3)
        }
        
        // Get last document for pagination (last document from sorted list)
        let lastDoc = limitedPosts.last?.document
        
        Logger.info("Returning \(filteredPosts.count) posts from home feed", service: "FeedService")
        Logger.debug("Has follows: \(hasFollows)", service: "FeedService")
        
        return (filteredPosts, lastDoc, hasFollows)
    }
    
    // Note: Removed loadEngagementMetrics method
    // We now use metrics directly from Post objects loaded from Firestore
    // This prevents re-ranking during scrolling and ensures feed stability
    // Metrics are only updated when the feed is explicitly refreshed
}

