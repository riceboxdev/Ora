//
//  ImageUploadService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import UIKit
import FirebaseFunctions
import FirebaseAuth

class ImageUploadService {
    // Active upload tasks for cancellation support
    private var activeUploads: [UUID: URLSessionDataTask] = [:]
    private let uploadQueue = DispatchQueue(label: "com.orabeta.uploadservice", attributes: .concurrent)
    
    init() {
        // Validate configuration
        guard !Config.cloudflareAccountId.isEmpty, Config.cloudflareAccountId != "YOUR_ACCOUNT_ID" else {
            fatalError("Cloudflare account ID is not configured. Please set it in Config.swift")
        }
    }
    
    // Get Functions instance - create it fresh each time to ensure it has current auth state
    private var functions: Functions {
        return FunctionsConfig.functions(region: "us-central1")
    }
    
    /// Cancel an active upload
    func cancelUpload(uploadId: UUID) {
        uploadQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let task = self.activeUploads[uploadId] {
                Logger.info("Cancelling upload \(uploadId)", service: "ImageUploadService")
                task.cancel()
                self.activeUploads.removeValue(forKey: uploadId)
            }
        }
    }
    
    /// Cancel all active uploads
    func cancelAllUploads() {
        uploadQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            Logger.info("Cancelling all \(self.activeUploads.count) active uploads", service: "ImageUploadService")
            for (_, task) in self.activeUploads {
                task.cancel()
            }
            self.activeUploads.removeAll()
        }
    }
    
    /// Upload image data to Cloudflare Images
    /// Only uploads the original image - thumbnail URL is generated using Cloudflare transformations
    func uploadImageData(
        uploadId: UUID,
        imageData: Data,
        thumbnailData: Data, // Kept for compatibility but not used
        userId: String,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws -> (imageUrl: String, thumbnailUrl: String) {
        print("🌐 ImageUploadService: Starting Cloudflare image upload")
        print("   Upload ID: \(uploadId)")
        print("   User ID: \(userId)")
        print("   Image data size: \(String(format: "%.2f", Double(imageData.count) / (1024 * 1024))) MB")
        
        Logger.info("Starting Cloudflare image upload", service: "ImageUploadService")
        Logger.debug("   Upload ID: \(uploadId)", service: "ImageUploadService")
        Logger.debug("   User ID: \(userId)", service: "ImageUploadService")
        Logger.debug("   Image data size: \(String(format: "%.2f", Double(imageData.count) / (1024 * 1024))) MB", service: "ImageUploadService")
        
        let totalStartTime = Date()
        
        // Upload only the original image
        let imageUrl = try await uploadToCloudflare(
            uploadId: uploadId,
            imageData: imageData,
            userId: userId,
            progressCallback: progressCallback
        )
        
        // Generate thumbnail URL using Cloudflare transformations
        // Format: https://<ZONE>/cdn-cgi/image/<OPTIONS>/<SOURCE-IMAGE>
        // For thumbnails, we use width=400,fit=scale-down,quality=75
        let thumbnailUrl = generateThumbnailUrl(from: imageUrl)
        
        print("🖼️ ImageUploadService: Generated thumbnail URL: \(thumbnailUrl)")
        print("   From image URL: \(imageUrl)")
        
        // Clean up from active uploads
        uploadQueue.async(flags: .barrier) { [weak self] in
            self?.activeUploads.removeValue(forKey: uploadId)
        }
        
        let totalDuration = Date().timeIntervalSince(totalStartTime)
        Logger.info("Cloudflare upload completed successfully!", service: "ImageUploadService")
        Logger.debug("   Total duration: \(String(format: "%.2f", totalDuration))s", service: "ImageUploadService")
        Logger.debug("   Full image URL: \(imageUrl)", service: "ImageUploadService")
        Logger.debug("   Thumbnail URL: \(thumbnailUrl)", service: "ImageUploadService")
        
        return (imageUrl, thumbnailUrl)
    }
    
    /// Upload image to Cloudflare (legacy method for compatibility)
    func uploadImage(_ image: UIImage, userId: String) async throws -> (imageUrl: String, thumbnailUrl: String) {
        Logger.info("Starting image upload (legacy method)", service: "ImageUploadService")
        Logger.debug("   User ID: \(userId)", service: "ImageUploadService")
        Logger.debug("   Image size: \(image.size.width)x\(image.size.height)", service: "ImageUploadService")
        Logger.debug("   Image scale: \(image.scale)", service: "ImageUploadService")
        
        // Process image using ImageProcessor
        guard let processed = await ImageProcessor.shared.processImage(image) else {
            Logger.error("Failed to process image", service: "ImageUploadService")
            throw ImageUploadError.invalidImage
        }
        
        // Use the optimized upload method (generate a UUID for this upload)
        return try await uploadImageData(
            uploadId: UUID(),
            imageData: processed.fullImageData,
            thumbnailData: processed.thumbnailData,
            userId: userId,
            progressCallback: nil
        )
    }
    
    /// Generate thumbnail URL from Cloudflare image URL
    /// 
    /// NOTE: Cloudflare Image variants are not available in the current plan.
    /// We return the same URL for both full image and thumbnail.
    /// Client-side downsampling (via CachedImageView) will handle thumbnail display.
    /// 
    /// Reference: https://developers.cloudflare.com/images/
    private func generateThumbnailUrl(from imageUrl: String) -> String {
        // Without Cloudflare variant support, use the same URL for thumbnails
        // CachedImageView will downsample for display
        Logger.info("Using main image URL for thumbnail (variants not available)", service: "ImageUploadService")
        Logger.debug("URL: \(imageUrl)", service: "ImageUploadService")
        return imageUrl
    }
    
    /// Get upload URL and token from Firebase Function
    private func getCloudflareUploadInfo(userId: String) async throws -> (uploadUrl: String, apiToken: String) {
        // Verify user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            Logger.error("User is not authenticated", service: "ImageUploadService")
            throw ImageUploadError.uploadFailedWithMessage("User must be authenticated to upload images")
        }
        
        Logger.info("User authenticated - \(currentUser.uid)", service: "ImageUploadService")
        
        // Force refresh the ID token to ensure it's valid
        Logger.debug("Refreshing auth token...", service: "ImageUploadService")
        do {
            let token = try await currentUser.getIDToken(forcingRefresh: true)
            Logger.info("Auth token refreshed successfully", service: "ImageUploadService")
            Logger.debug("   Token length: \(token.count) characters", service: "ImageUploadService")
        } catch {
            Logger.warning("Failed to refresh auth token: \(error.localizedDescription)", service: "ImageUploadService")
            Logger.debug("   Continuing anyway - Firebase SDK should handle token refresh automatically", service: "ImageUploadService")
        }
        
        print("📞 ImageUploadService: Calling Firebase Function 'uploadToCloudflare' with userId: \(userId)")
        Logger.info("Calling Firebase Function 'uploadToCloudflare' with userId: \(userId)", service: "ImageUploadService")
        
        let function = functions.httpsCallable("uploadToCloudflare")
        
        do {
            print("⏳ ImageUploadService: Waiting for Firebase Function response...")
            Logger.debug("Waiting for Firebase Function response...", service: "ImageUploadService")
            Logger.debug("   Auth token present: \(currentUser.uid)", service: "ImageUploadService")
            
            let result = try await function.call([
                "userId": userId
            ])
            
            Logger.info("Received response from Firebase Function", service: "ImageUploadService")
            
            guard let data = result.data as? [String: Any] else {
                Logger.error("Invalid response format - result.data is not a dictionary", service: "ImageUploadService")
                Logger.debug("   Response: \(String(describing: result.data))", service: "ImageUploadService")
                throw ImageUploadError.invalidConfiguration
            }
            
            Logger.debug("Parsing response data: \(data.keys.joined(separator: ", "))", service: "ImageUploadService")
            
            guard let uploadUrl = data["uploadUrl"] as? String else {
                Logger.error("Missing 'uploadUrl' in response", service: "ImageUploadService")
                throw ImageUploadError.invalidConfiguration
            }
            
            guard let apiToken = data["apiToken"] as? String else {
                Logger.error("Missing 'apiToken' in response", service: "ImageUploadService")
                throw ImageUploadError.invalidConfiguration
            }
            
            print("✅ ImageUploadService: Successfully received upload info from Firebase Function")
            print("   Upload URL: \(uploadUrl)")
            print("   API token length: \(apiToken.count) characters")
            print("   API token prefix: \(String(apiToken.prefix(10)))...")
            
            Logger.info("Successfully received upload info", service: "ImageUploadService")
            Logger.debug("   Upload URL: \(uploadUrl)", service: "ImageUploadService")
            Logger.debug("   API token length: \(apiToken.count) characters", service: "ImageUploadService")
            Logger.debug("   API token prefix: \(String(apiToken.prefix(10)))...", service: "ImageUploadService")
            
            return (uploadUrl: uploadUrl, apiToken: apiToken)
        } catch {
            Logger.error("Firebase Function call failed: \(error.localizedDescription)", service: "ImageUploadService")
            if let nsError = error as NSError? {
                Logger.debug("   Error domain: \(nsError.domain)", service: "ImageUploadService")
                Logger.debug("   Error code: \(nsError.code)", service: "ImageUploadService")
                Logger.debug("   User info: \(nsError.userInfo)", service: "ImageUploadService")
                
                // Check if it's an authentication error
                if nsError.code == 16 || nsError.domain.contains("UNAUTHENTICATED") {
                    Logger.warning("Authentication error - user may not be properly authenticated", service: "ImageUploadService")
                    Logger.debug("   Current user: \(Auth.auth().currentUser?.uid ?? "nil")", service: "ImageUploadService")
                    Logger.debug("   Try refreshing the auth token or signing in again", service: "ImageUploadService")
                }
            }
            throw ImageUploadError.uploadFailedWithMessage("Failed to get upload info: \(error.localizedDescription)")
        }
    }
    
    /// Upload image data to Cloudflare Images API
    /// Documentation: https://developers.cloudflare.com/images/upload-images/upload-via-url/
    private func uploadToCloudflare(
        uploadId: UUID,
        imageData: Data,
        userId: String,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws -> String {
        // Validate image data
        guard !imageData.isEmpty else {
            Logger.error("Empty image data", service: "ImageUploadService")
            throw ImageUploadError.invalidImage
        }
        
        let fileSize = imageData.count
        let fileSizeMB = Double(fileSize) / (1024 * 1024)
        
        Logger.info("Requesting upload info from Firebase Function", service: "ImageUploadService")
        Logger.debug("   Upload ID: \(uploadId)", service: "ImageUploadService")
        Logger.debug("   User ID: \(userId)", service: "ImageUploadService")
        Logger.debug("   Size: \(String(format: "%.2f", fileSizeMB)) MB", service: "ImageUploadService")
        
        // Get upload URL and API token from Firebase Function
        let uploadInfo = try await getCloudflareUploadInfo(userId: userId)
        
        // Use the upload URL from Firebase Function (it already has the correct account ID)
        let uploadUrl = uploadInfo.uploadUrl
        
        print("🔗 ImageUploadService: Using upload URL: \(uploadUrl)")
        print("🔑 ImageUploadService: API token length: \(uploadInfo.apiToken.count) characters")
        print("🔑 ImageUploadService: API token prefix: \(String(uploadInfo.apiToken.prefix(10)))...")
        
        Logger.debug("Using upload URL: \(uploadUrl)", service: "ImageUploadService")
        Logger.debug("API token length: \(uploadInfo.apiToken.count) characters", service: "ImageUploadService")
        Logger.debug("API token prefix: \(String(uploadInfo.apiToken.prefix(10)))...", service: "ImageUploadService")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "POST"
        // Cloudflare Images API uses Bearer token authentication
        // The token should be a valid API token with Images:Edit permissions
        request.setValue("Bearer \(uploadInfo.apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        Logger.debug("Request headers set", service: "ImageUploadService")
        Logger.debug("   Authorization: Bearer [\(uploadInfo.apiToken.count) chars]", service: "ImageUploadService")
        
        // Build multipart body
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add metadata (optional)
        let metadata = ["userId": userId]
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add requireSignedURLs (optional, default false)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"requireSignedURLs\"\r\n\r\n".data(using: .utf8)!)
        body.append("false".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Create URLSession with progress tracking
        let session = URLSession(configuration: .default)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                self.handleUploadCompletion(
                    uploadId: uploadId,
                    data: data,
                    response: response,
                    error: error,
                    continuation: continuation
                )
            }
            
            // Store task for cancellation support
            self.uploadQueue.async(flags: .barrier) { [weak self] in
                self?.activeUploads[uploadId] = task
            }
            
            // Start the upload
            task.resume()
            
            // Note: URLSession doesn't provide easy progress tracking for multipart uploads
            // We'll simulate progress based on upload completion
            // For real progress tracking, we'd need to use URLSessionUploadTask with a file
            if let progressCallback = progressCallback {
                // Simulate progress (this is a limitation of URLSession with Data)
                // In production, you might want to use URLSessionUploadTask with a file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    progressCallback(0.5)
                }
            }
        }
    }
    
    /// Handle upload completion
    private func handleUploadCompletion(
        uploadId: UUID,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        continuation: CheckedContinuation<String, Error>
    ) {
        // Remove from active uploads
        uploadQueue.async(flags: .barrier) { [weak self] in
            self?.activeUploads.removeValue(forKey: uploadId)
        }
        
        if let error = error {
            Logger.error("Cloudflare upload error - Upload ID: \(uploadId), Description: \(error.localizedDescription)", service: "ImageUploadService")
            
            continuation.resume(throwing: ImageUploadError.uploadFailedWithMessage(
                "Cloudflare upload failed: \(error.localizedDescription)"
            ))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid response type", service: "ImageUploadService")
            continuation.resume(throwing: ImageUploadError.uploadFailedWithMessage(
                "Invalid response from server"
            ))
            return
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let statusCode = httpResponse.statusCode
            let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
            
            print("❌ ImageUploadService: Cloudflare upload failed with status \(statusCode)")
            print("   Error: \(errorMessage)")
            
            Logger.error("Cloudflare upload failed with status \(statusCode): \(errorMessage)", service: "ImageUploadService")
            
            // Provide more helpful error messages for common issues
            if statusCode == 400 {
                if errorMessage.contains("10001") || errorMessage.contains("Unable to authenticate") {
                    print("❌ ImageUploadService: Authentication failed!")
                    print("   The Cloudflare API token is invalid, expired, or missing Images:Edit permission")
                    print("   Please update CLOUDFLARE_API_TOKEN in Firebase Functions environment variables")
                    Logger.error("Authentication failed - API token may be invalid, expired, or missing Images:Edit permission", service: "ImageUploadService")
                    Logger.error("   Please verify the Cloudflare API token in Firebase Functions environment variables", service: "ImageUploadService")
                    Logger.error("   Token must have 'Images:Edit' permission for the account", service: "ImageUploadService")
                }
            }
            
            continuation.resume(throwing: ImageUploadError.uploadFailedWithMessage(
                "Upload failed with status \(statusCode): \(errorMessage)"
            ))
            return
        }
        
        guard let data = data else {
            Logger.error("No data in response", service: "ImageUploadService")
            continuation.resume(throwing: ImageUploadError.uploadFailedWithMessage(
                "No data received from server"
            ))
            return
        }
        
        // Parse Cloudflare response
        // Expected format: { "result": { "id": "...", "variants": ["...", "..."] }, "success": true }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let variants = result["variants"] as? [String],
                  let imageUrl = variants.first else {
                Logger.error("Invalid response format from Cloudflare", service: "ImageUploadService")
                Logger.debug("   Response: \(String(data: data, encoding: .utf8) ?? "nil")", service: "ImageUploadService")
                throw ImageUploadError.uploadFailedWithMessage("Invalid response format from Cloudflare")
            }
            
            print("✅ ImageUploadService: Upload successful - Upload ID: \(uploadId)")
            print("   Image URL: \(imageUrl)")
            print("   All variants: \(variants)")
            
            Logger.info("Upload successful - Upload ID: \(uploadId)", service: "ImageUploadService")
            Logger.debug("   Image URL: \(imageUrl)", service: "ImageUploadService")
            
            continuation.resume(returning: imageUrl)
        } catch {
            Logger.error("Failed to parse Cloudflare response: \(error.localizedDescription)", service: "ImageUploadService")
            Logger.debug("   Response: \(String(data: data, encoding: .utf8) ?? "nil")", service: "ImageUploadService")
            continuation.resume(throwing: ImageUploadError.uploadFailedWithMessage(
                "Failed to parse upload response: \(error.localizedDescription)"
            ))
        }
    }
}

enum ImageUploadError: LocalizedError {
    case invalidImage
    case uploadFailed
    case uploadFailedWithMessage(String)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image data"
        case .uploadFailed:
            return "Failed to upload image to Cloudflare"
        case .uploadFailedWithMessage(let message):
            return message
        case .invalidConfiguration:
            return "Cloudflare configuration is invalid. Please check your account ID and API token in Config.swift"
        }
    }
}
