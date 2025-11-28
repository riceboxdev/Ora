//
//  ImageMigrationService.swift
//  OraBeta
//
//  Created by Migration Tool
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import UIKit

struct MigrationProgress {
    let total: Int
    let processed: Int
    let migrated: Int
    let failed: Int
    let currentPostId: String?
}

struct MigrationResult {
    let processed: Int
    let migrated: Int
    let failed: Int
    let errors: [String]
    let nextStartAfter: String?
    let hasMore: Bool
}

class ImageMigrationService {
    private let db = Firestore.firestore()
    private let imageUploadService = ImageUploadService()
    private let functions = FunctionsConfig.functions(region: "us-central1")
    
    /// Migrate images from Cloudinary to Cloudflare
    /// - Parameters:
    ///   - limit: Maximum number of posts to process (default: 10, max: 100)
    ///   - batchSize: Number of posts to process in parallel (default: 5, max: 10)
    ///   - dryRun: If true, only logs what would be migrated without actually migrating
    ///   - startAfter: Post ID to start after (for pagination)
    ///   - progressCallback: Called with progress updates
    /// - Returns: Migration result with statistics
    func migrateImages(
        limit: Int = 10,
        batchSize: Int = 5,
        dryRun: Bool = false,
        startAfter: String? = nil,
        progressCallback: ((MigrationProgress) -> Void)? = nil
    ) async throws -> MigrationResult {
        print("🔄 ImageMigrationService: Starting migration")
        print("   Limit: \(limit)")
        print("   Batch size: \(batchSize)")
        print("   Dry run: \(dryRun)")
        
        // Verify user is authenticated
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ImageMigrationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User must be authenticated"])
        }
        
        // Query posts - we'll filter for Cloudinary URLs client-side
        // Note: Firestore doesn't support substring queries efficiently
        // For better performance in the future, consider adding an "imageProvider" field to posts
        var query = db.collection("posts")
            .limit(to: min(limit * 2, 200)) // Fetch more to account for filtering
        
        if let startAfter = startAfter {
            let startAfterDoc = try await db.collection("posts").document(startAfter).getDocument()
            if startAfterDoc.exists {
                query = query.start(afterDocument: startAfterDoc)
            }
        }
        
        let snapshot = try await query.getDocuments()
        
        // Filter for Cloudinary URLs client-side
        let allPosts = snapshot.documents
        let posts = allPosts.filter { doc in
            let postData = doc.data()
            if let imageUrl = postData["imageUrl"] as? String {
                return imageUrl.contains("cloudinary.com") && !imageUrl.contains("imagedelivery.net")
            }
            return false
        }
        
        if posts.isEmpty {
            print("✅ ImageMigrationService: No posts with Cloudinary URLs found")
            return MigrationResult(
                processed: 0,
                migrated: 0,
                failed: 0,
                errors: [],
                nextStartAfter: allPosts.last?.documentID,
                hasMore: allPosts.count == limit * 2
            )
        }
        var processed = 0
        var migrated = 0
        var failed = 0
        var errors: [String] = []
        var nextStartAfter: String? = posts.last?.documentID
        
        print("📋 ImageMigrationService: Found \(posts.count) posts with Cloudinary URLs")
        
        // Process posts in batches
        for i in stride(from: 0, to: posts.count, by: batchSize) {
            let batch = Array(posts[i..<min(i + batchSize, posts.count)])
            let batchNumber = (i / batchSize) + 1
            let totalBatches = Int(ceil(Double(posts.count) / Double(batchSize)))
            
            print("📦 ImageMigrationService: Processing batch \(batchNumber)/\(totalBatches) (\(batch.count) posts)")
            
            // Process batch in parallel
            await withTaskGroup(of: (String, Bool, String?).self) { group in
                for doc in batch {
                    group.addTask { [weak self] in
                        guard let self = self else {
                            return (doc.documentID, false, "Service deallocated")
                        }
                        return await self.migratePost(
                            document: doc,
                            userId: userId,
                            dryRun: dryRun
                        )
                    }
                }
                
                for await (postId, success, error) in group {
                    processed += 1
                    if success {
                        migrated += 1
                    } else {
                        failed += 1
                        if let error = error {
                            errors.append("Post \(postId): \(error)")
                        }
                    }
                    
                    // Update progress
                    progressCallback?(MigrationProgress(
                        total: posts.count,
                        processed: processed,
                        migrated: migrated,
                        failed: failed,
                        currentPostId: postId
                    ))
                }
            }
            
            // Small delay between batches to avoid rate limiting
            if i + batchSize < posts.count {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        let result = MigrationResult(
            processed: processed,
            migrated: migrated,
            failed: failed,
            errors: errors,
            nextStartAfter: nextStartAfter,
            hasMore: posts.count == limit
        )
        
        print("✅ ImageMigrationService: Migration completed")
        print("   Processed: \(result.processed)")
        print("   Migrated: \(result.migrated)")
        print("   Failed: \(result.failed)")
        
        return result
    }
    
    /// Migrate a single post
    private func migratePost(
        document: QueryDocumentSnapshot,
        userId: String,
        dryRun: Bool
    ) async -> (String, Bool, String?) {
        let postId = document.documentID
        let postData = document.data()
        
        print("🔍 ImageMigrationService: Processing post \(postId)")
        print("   Post owner: \(postData["userId"] as? String ?? "unknown")")
        print("   Current user: \(userId)")
        
        // Verify the post belongs to the current user
        if let postUserId = postData["userId"] as? String, postUserId != userId {
            print("⚠️ ImageMigrationService: Post \(postId) belongs to user \(postUserId), not \(userId). Skipping.")
            return (postId, false, "Post belongs to different user")
        }
        
        guard let imageUrl = postData["imageUrl"] as? String else {
            print("❌ ImageMigrationService: Post \(postId) has no imageUrl")
            return (postId, false, "No imageUrl found")
        }
        
        print("   Current imageUrl: \(imageUrl)")
        
        // Skip if already migrated
        if imageUrl.contains("imagedelivery.net") {
            print("⏭️ ImageMigrationService: Post \(postId) already has Cloudflare URL, skipping")
            return (postId, false, "Already migrated")
        }
        
        guard imageUrl.contains("cloudinary.com") else {
            print("⚠️ ImageMigrationService: Post \(postId) does not have Cloudinary URL, skipping")
            return (postId, false, "Not a Cloudinary URL")
        }
        
        if dryRun {
            print("🔍 [DRY RUN] ImageMigrationService: Would migrate post \(postId): \(imageUrl)")
            return (postId, true, nil)
        }
        
        do {
            // Verify post still exists before proceeding
            let postRef = db.collection("posts").document(postId)
            let postDoc = try await postRef.getDocument()
            
            if !postDoc.exists {
                print("❌ ImageMigrationService: Post \(postId) no longer exists in Firestore (may have been deleted)")
                return (postId, false, "Post no longer exists")
            }
            
            // Download image from Cloudinary
            print("⬇️ ImageMigrationService: Downloading image for post \(postId)")
            let imageData = try await downloadImage(from: imageUrl)
            print("✅ ImageMigrationService: Downloaded \(imageData.count) bytes for post \(postId)")
            
            // Upload to Cloudflare
            print("⬆️ ImageMigrationService: Uploading image for post \(postId) to Cloudflare")
            let uploadId = UUID()
            let (newImageUrl, newThumbnailUrl) = try await imageUploadService.uploadImageData(
                uploadId: uploadId,
                imageData: imageData,
                thumbnailData: imageData, // Not used but required
                userId: userId
            )
            
            print("✅ ImageMigrationService: Uploaded post \(postId) to Cloudflare: \(newImageUrl)")
            
            // Update Firestore via Firebase Function
            // Note: We can't update directly due to Firestore security rules
            try await updatePostInFirestore(
                postId: postId,
                imageUrl: newImageUrl,
                thumbnailUrl: newThumbnailUrl,
                originalCloudinaryUrl: imageUrl,
                originalCloudinaryThumbnailUrl: postData["thumbnailUrl"] as? String
            )
            
            print("✅ ImageMigrationService: Successfully migrated post \(postId)")
            return (postId, true, nil)
        } catch {
            let errorMsg = error.localizedDescription
            print("❌ ImageMigrationService: Failed to migrate post \(postId): \(errorMsg)")
            print("   Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
            }
            return (postId, false, errorMsg)
        }
    }
    
    /// Download image from URL
    private func downloadImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ImageMigrationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ImageMigrationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download image: \(response)"])
        }
        
        return data
    }
    
    /// Update post in Firestore via Firebase Function
    /// This is needed because Firestore security rules prevent direct client-side updates
    private func updatePostInFirestore(
        postId: String,
        imageUrl: String,
        thumbnailUrl: String,
        originalCloudinaryUrl: String,
        originalCloudinaryThumbnailUrl: String?
    ) async throws {
        print("🔄 ImageMigrationService: Updating post \(postId) in Firestore")
        print("   New imageUrl: \(imageUrl)")
        print("   New thumbnailUrl: \(thumbnailUrl)")
        print("   Original Cloudinary URL: \(originalCloudinaryUrl)")
        
        let function = functions.httpsCallable("updatePostImageUrls")
        
        var requestData: [String: Any] = [
            "postId": postId,
            "imageUrl": imageUrl,
            "thumbnailUrl": thumbnailUrl,
            "originalCloudinaryUrl": originalCloudinaryUrl
        ]
        
        if let originalThumbnail = originalCloudinaryThumbnailUrl {
            requestData["originalCloudinaryThumbnailUrl"] = originalThumbnail
        }
        
        print("📤 ImageMigrationService: Calling updatePostImageUrls function with data:")
        print("   postId: \(postId)")
        print("   imageUrl: \(imageUrl)")
        print("   thumbnailUrl: \(thumbnailUrl)")
        
        do {
            let result = try await function.call(requestData)
            
            if let resultData = result.data as? [String: Any] {
                print("✅ ImageMigrationService: Successfully updated post \(postId) in Firestore")
                print("   Result: \(resultData)")
            } else {
                print("✅ ImageMigrationService: Updated post \(postId) in Firestore (no result data)")
            }
        } catch let error as NSError {
            print("❌ ImageMigrationService: Failed to update post \(postId) in Firestore")
            print("   Error domain: \(error.domain)")
            print("   Error code: \(error.code)")
            print("   Error description: \(error.localizedDescription)")
            print("   Error userInfo: \(error.userInfo)")
            
            // Try to extract more details from Firebase error
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying error: \(underlyingError.localizedDescription)")
            }
            
            // Check if it's a Firebase Functions error
            if let functionsError = error.userInfo["FunctionsErrorCode"] as? String {
                print("   Functions error code: \(functionsError)")
            }
            if let functionsMessage = error.userInfo["FunctionsErrorDetails"] as? String {
                print("   Functions error message: \(functionsMessage)")
            }
            
            throw error
        }
    }
}

