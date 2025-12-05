//
//  PostService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
class PostService: PostServiceProtocol {
    private let db = Firestore.firestore()
    private let profileService: ProfileService
    private let blockedUsersService: BlockedUsersService
    private let classificationService: PostClassificationService
    private let functions = FunctionsConfig.functions(region: "us-central1")
    
    init(
        profileService: ProfileService,
        blockedUsersService: BlockedUsersService? = nil,
        classificationService: PostClassificationService? = nil
    ) {
        Logger.info("Initializing", service: "PostService")
        self.profileService = profileService
        self.blockedUsersService = blockedUsersService ?? BlockedUsersService()
        self.classificationService = classificationService ?? PostClassificationService()
    }
    
    /// Create a new post - saves to Firestore via Firebase Function
    func createPost(
        userId: String,
        imageUrl: String,
        thumbnailUrl: String?,
        imageWidth: Int?,
        imageHeight: Int?,
        caption: String?,
        interestIds: [String]?
    ) async throws -> String {
        print("📝 PostService: Creating post via Firebase Function")
        print("   User ID: \(userId)")
        print("   Image URL: \(imageUrl)")
        print("   Thumbnail URL: \(thumbnailUrl ?? "none")")
        
        Logger.info("Creating post via Firebase Function", service: "PostService")
        Logger.debug("   User ID: \(userId)", service: "PostService")
        Logger.debug("   Image URL: \(imageUrl)", service: "PostService")
        Logger.debug("   Thumbnail URL: \(thumbnailUrl ?? "none")", service: "PostService")
        Logger.debug("   Image dimensions: \(imageWidth ?? 0)x\(imageHeight ?? 0)", service: "PostService")
        Logger.debug("   Caption: \(caption ?? "none")", service: "PostService")
        Logger.debug("   Interests: \(interestIds?.joined(separator: ", ") ?? "none")", service: "PostService")

        let startTime = Date()
        
        // Call Firebase Function to create post
        // Note: userId is not needed in request - Firebase Function gets it from auth context
        let function = functions.httpsCallable("createPost")
        var requestData: [String: Any] = [
            "imageUrl": imageUrl
        ]
        
        if let thumbnailUrl = thumbnailUrl {
            requestData["thumbnailUrl"] = thumbnailUrl
        }
        
        if let imageWidth = imageWidth {
            requestData["imageWidth"] = imageWidth
        }
        
        if let imageHeight = imageHeight {
            requestData["imageHeight"] = imageHeight
        }
        
        if let caption = caption {
            requestData["caption"] = caption
        }
        
        if let interestIds = interestIds {
            requestData["interestIds"] = interestIds
        }
        
        // Check authentication before calling function
        guard let currentUser = Auth.auth().currentUser else {
            Logger.error("No authenticated user", service: "PostService")
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Refresh auth token if needed
        do {
            _ = try await currentUser.getIDToken(forcingRefresh: false)
        } catch {
            Logger.warning("Failed to get ID token: \(error.localizedDescription)", service: "PostService")
            // Try to refresh the token
            do {
                _ = try await currentUser.getIDToken(forcingRefresh: true)
                Logger.info("Successfully refreshed auth token", service: "PostService")
            } catch {
                Logger.error("Failed to refresh auth token: \(error.localizedDescription)", service: "PostService")
                throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(error.localizedDescription)"])
            }
        }
        
        // Configure function call with timeout (if supported)
        // Note: Timeout is typically handled by Firebase Functions SDK automatically
        
        let result: HTTPSCallableResult
        do {
            result = try await function.call(requestData)
        } catch let error as NSError {
            Logger.error("Firebase Function call failed", service: "PostService")
            Logger.error("   Error domain: \(error.domain)", service: "PostService")
            Logger.error("   Error code: \(error.code)", service: "PostService")
            Logger.error("   Error description: \(error.localizedDescription)", service: "PostService")
            
            // Provide more helpful error messages
            if error.domain == "FIRFunctionsErrorDomain" {
                switch error.code {
                case -1: // UNAVAILABLE
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service temporarily unavailable. Please check your internet connection and try again."])
                case -2: // DEADLINE_EXCEEDED
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
                case -3: // NOT_FOUND
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Function not found. Please contact support."])
                case -4: // ALREADY_EXISTS
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post already exists."])
                case -5: // PERMISSION_DENIED
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please sign in again."])
                case -6: // UNAUTHENTICATED
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."])
                default:
                    throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create post: \(error.localizedDescription)"])
                }
            }
            throw error
        }
        
        let response = result.data as? [String: Any] ?? [:]
        
        guard let success = response["success"] as? Bool, success,
              let postId = response["postId"] as? String ?? response["activityId"] as? String else {
            Logger.error("Invalid response from createPost function", service: "PostService")
            Logger.error("   Response: \(response)", service: "PostService")
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create post: Invalid response from server"])
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Logger.info("Post created successfully", service: "PostService")
        Logger.info("   Post ID: \(postId)", service: "PostService")
        Logger.debug("   Duration: \(String(format: "%.2f", duration))s", service: "PostService")
        Logger.info("Post creation completed successfully!", service: "PostService")

        return postId
    }
    
    /// Edit a post - updates Firestore via Firebase Function
    /// Only the post owner can edit their posts
    func editPost(
        postId: String,
        caption: String?,
        interestIds: [String]?
    ) async throws {
        Logger.info("Editing post", service: "PostService")
        Logger.debug("   Post ID: \(postId)", service: "PostService")
        Logger.debug("   Caption: \(caption ?? "none")", service: "PostService")
        Logger.debug("   Interests: \(interestIds?.joined(separator: ", ") ?? "none")", service: "PostService")
        
        let function = functions.httpsCallable("editPost")
        var requestData: [String: Any] = [
            "activityId": postId // Keep activityId for backwards compatibility
        ]
        
        if let caption = caption {
            requestData["caption"] = caption
        }
        
        if let interestIds = interestIds {
            requestData["interestIds"] = interestIds
        }
        
        let result = try await function.call(requestData)
        let response = result.data as? [String: Any] ?? [:]
        
        guard let success = response["success"] as? Bool, success else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to edit post"])
        }
        
        Logger.info("Post edited successfully", service: "PostService")
    }
    
    /// Get posts from Firestore
    /// - Parameters:
    ///   - userId: Optional user ID to filter posts by user (for user profile)
    ///   - limit: Maximum number of posts to return
    ///   - lastDocument: Last document for pagination (optional)
    /// - Returns: Array of posts
    func getPosts(
        userId: String? = nil,
        limit: Int = 20,
        lastDocument: QueryDocumentSnapshot? = nil
    ) async throws -> (posts: [Post], lastDocument: QueryDocumentSnapshot?) {
        Logger.info("Getting posts from Firestore", service: "PostService")
        Logger.debug("   User ID: \(userId ?? "all")", service: "PostService")
        Logger.debug("   Limit: \(limit)", service: "PostService")
        
        // Build query
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
        
        // Filter by user if provided
        if let userId = userId {
            query = query.whereField("userId", isEqualTo: userId)
        }
        
        // Apply pagination if lastDocument is provided
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        // Limit results
        query = query.limit(to: limit)
        
        // Fetch posts
        let snapshot = try await query.getDocuments()
        Logger.info("Fetched \(snapshot.documents.count) posts from Firestore", service: "PostService")
        
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
                Logger.info("Batch fetched \(profiles.count) profiles for \(userIds.count) unique users", service: "PostService")
            } catch {
                Logger.warning("Failed to batch fetch profiles: \(error.localizedDescription)", service: "PostService")
                profiles = [:]
            }
        } else {
            profiles = [:]
        }
        
        // Convert Firestore documents to Posts (using batched profiles)
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
                Logger.info("Filtered out \(filteredCount) post(s) from blocked users", service: "PostService")
            }
        } catch {
            Logger.warning("Failed to get blocked users, showing all posts: \(error.localizedDescription)", service: "PostService")
            filteredPosts = posts
        }
        
        Logger.info("Retrieved \(filteredPosts.count) posts from Firestore", service: "PostService")
        
        // Get last document for pagination
        let lastDoc = snapshot.documents.last
        
        return (posts: filteredPosts, lastDocument: lastDoc)
    }
    
    /// Delete a post - removes from Firestore via Firebase Function
    /// Only the post owner can delete their posts
    func deletePost(postId: String) async throws {
        Logger.info("Deleting post", service: "PostService")
        Logger.debug("   Post ID: \(postId)", service: "PostService")
        
        let function = functions.httpsCallable("deletePost")
        let requestData: [String: Any] = [
            "postId": postId
        ]
        
        let result = try await function.call(requestData)
        let response = result.data as? [String: Any] ?? [:]
        
        guard let success = response["success"] as? Bool, success else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete post"])
        }
        
        Logger.info("Post deleted successfully", service: "PostService")
    }
    
    /// Remove a specific tag from all posts (admin function)
    /// - Parameter tagToRemove: The tag to remove (case-insensitive)
    /// - Returns: Tuple with (updatedCount, errorCount)
    func removeTagFromAllPosts(_ tagToRemove: String) async throws -> (updatedCount: Int, errorCount: Int) {
        Logger.info("Removing tag '\(tagToRemove)' from all posts", service: "PostService")
        
        let normalizedTag = tagToRemove.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedTag.isEmpty else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tag cannot be empty"])
        }
        
        var updatedCount = 0
        var errorCount = 0
        
        // Process in batches to avoid memory issues
        let batchSize = 500 // Firestore batch limit is 500
        var lastDocument: QueryDocumentSnapshot? = nil
        
        repeat {
            // Build query - get all posts (we'll filter for ones with tags in code)
            var query: Query = db.collection("posts")
                .order(by: "createdAt", descending: false)
                .limit(to: batchSize)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            // Fetch batch
            let snapshot = try await query.getDocuments()
            
            if snapshot.documents.isEmpty {
                break
            }
            
            // Filter documents that actually have the tag
            let documentsWithTag = snapshot.documents.filter { doc in
                let data = doc.data()
                if let tags = data["tags"] as? [String] {
                    return tags.contains { $0.lowercased() == normalizedTag }
                }
                return false
            }
            
            // Process in smaller batches for updates
            let updateBatchSize = 500
            var documentsToUpdate = documentsWithTag
            
            while !documentsToUpdate.isEmpty {
                let batch = db.batch()
                let currentBatch = Array(documentsToUpdate.prefix(updateBatchSize))
                documentsToUpdate = Array(documentsToUpdate.dropFirst(updateBatchSize))
                
                var batchUpdateCount = 0
                for document in currentBatch {
                    let data = document.data()
                    if let currentTags = data["tags"] as? [String] {
                        // Remove the tag (case-insensitive)
                        let filteredTags = currentTags.filter { $0.lowercased() != normalizedTag }
                        
                        // Only update if the tag was actually present
                        if filteredTags.count < currentTags.count {
                            let docRef = db.collection("posts").document(document.documentID)
                            batch.updateData([
                                "tags": filteredTags,
                                "updatedAt": FieldValue.serverTimestamp()
                            ], forDocument: docRef)
                            batchUpdateCount += 1
                        }
                    }
                }
                
                do {
                    if batchUpdateCount > 0 {
                        try await batch.commit()
                        updatedCount += batchUpdateCount
                        Logger.debug("   Updated batch of \(batchUpdateCount) posts", service: "PostService")
                    }
                } catch {
                    Logger.error("   Failed to update batch: \(error.localizedDescription)", service: "PostService")
                    errorCount += batchUpdateCount
                }
            }
            
            lastDocument = snapshot.documents.last
            
        } while lastDocument != nil
        
        Logger.info("Removed tag '\(tagToRemove)' from \(updatedCount) posts", service: "PostService")
        if errorCount > 0 {
            Logger.warning("   Failed to update \(errorCount) posts", service: "PostService")
        }
        
        return (updatedCount: updatedCount, errorCount: errorCount)
    }
    
    /// Delete all posts without tags (admin function)
    /// This deletes all posts that have no tags (null, empty array, or missing tags field)
    /// - Returns: Tuple with (deletedCount, errorCount)
    func deletePostsWithoutTags() async throws -> (deletedCount: Int, errorCount: Int) {
        Logger.info("Deleting all posts without tags", service: "PostService")
        
        var deletedCount = 0
        var errorCount = 0
        
        // Process in batches to avoid memory issues
        let batchSize = 500 // Firestore batch limit
        var lastDocument: QueryDocumentSnapshot? = nil
        
        repeat {
            // Build query - get all posts
            var query: Query = db.collection("posts")
                .order(by: "createdAt", descending: false)
                .limit(to: batchSize)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            // Fetch batch
            let snapshot = try await query.getDocuments()
            
            if snapshot.documents.isEmpty {
                break
            }
            
            // Filter documents that have no tags (null, empty array, or missing field)
            let postsToDelete = snapshot.documents.filter { doc in
                let data = doc.data()
                let tags = data["tags"] as? [String]
                // Post has no tags if: tags is null, undefined, empty array, or doesn't exist
                return tags == nil || tags?.isEmpty == true
            }
            
            // Delete posts in batches (Firestore batch limit is 500)
            let deleteBatchSize = 500
            var postsToDeleteRemaining = postsToDelete
            
            while !postsToDeleteRemaining.isEmpty {
                let batch = db.batch()
                let currentBatch = Array(postsToDeleteRemaining.prefix(deleteBatchSize))
                postsToDeleteRemaining = Array(postsToDeleteRemaining.dropFirst(deleteBatchSize))
                
                for document in currentBatch {
                    let docRef = db.collection("posts").document(document.documentID)
                    batch.deleteDocument(docRef)
                }
                
                do {
                    try await batch.commit()
                    deletedCount += currentBatch.count
                    Logger.debug("   Deleted batch of \(currentBatch.count) posts without tags", service: "PostService")
                } catch {
                    Logger.error("   Failed to delete batch: \(error.localizedDescription)", service: "PostService")
                    errorCount += currentBatch.count
                }
            }
            
            lastDocument = snapshot.documents.last
            
        } while lastDocument != nil
        
        Logger.info("Deleted \(deletedCount) posts without tags", service: "PostService")
        if errorCount > 0 {
            Logger.warning("   Failed to delete \(errorCount) posts", service: "PostService")
        }
        
        return (deletedCount: deletedCount, errorCount: errorCount)
    }
    
    // MARK: - Post Classification
    
    /// Classify a post and update it with interest data
    func classifyPostAndUpdate(postId: String) async throws -> PostInterestClassification? {
        do {
            let document = try await db.collection("posts").document(postId).getDocument()
            guard let firestoreData = document.data(),
                  let post = await Post.from(firestoreData: firestoreData, documentId: postId) else {
                return nil
            }
            
            let classification = try await classificationService.classifyPost(post)
            
            // Update post with classification data
            let topInterests = classification.topInterests(limit: 5)
            var interestScores: [String: Double] = [:]
            for interest in topInterests {
                interestScores[interest.interestId] = interest.confidence
            }
            
            let updateData: [String: Any] = [
                "interestIds": topInterests.map { $0.interestId },
                "interestScores": interestScores,
                "primaryInterestId": topInterests.first?.interestId as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("posts").document(postId).updateData(updateData)
            
            return classification
        } catch {
            Logger.warning("Failed to classify post \(postId): \(error.localizedDescription)", service: "PostService")
            return nil
        }
    }
    
    /// Suggest  interests for a post during creation
    func suggestInterestsForPost(
        caption: String? = nil,
        interestIds: [String]? = nil
    ) async throws -> [PostInterestClassification.Classification] {
        return try await classificationService.suggestInterestsForPost(
            caption: caption,
            tags: interestIds,  // Pass interests as tags to classification service for now
            boardId: nil
        )
    }
    
    /// Classify multiple posts in background (non-blocking)
    func classifyPostsInBackground(postIds: [String]) {
        Task {
            for postId in postIds {
                do {
                    _ = try await classifyPostAndUpdate(postId: postId)
                } catch {
                    Logger.debug("Background classification failed for post \(postId)", service: "PostService")
                }
            }
        }
    }
}
