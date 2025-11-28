//
//  WelcomeImageService.swift
//  OraBeta
//
//  Created by Nick Rogers on 12/21/25.
//

import Foundation
import FirebaseFirestore
import Combine
import Kingfisher

/// Service to fetch welcome screen image URLs from Firestore
@MainActor
class WelcomeImageService: ObservableObject {
    static let shared = WelcomeImageService()
    
    private let db = Firestore.firestore()
    private let collectionName = "welcome_screen_images"
    private let documentId = "main"
    
    @Published var images: [WelcomeImage] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cache: [WelcomeImage] = []
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    /// Fetch welcome screen images from Firestore
    func fetchImages() async {
        // Check cache first
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration,
           !cache.isEmpty {
            Logger.info("Using cached welcome images", service: "WelcomeImageService")
            self.images = cache
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let doc = try await db.collection(collectionName).document(documentId).getDocument()
            
            guard doc.exists, let data = doc.data() else {
                Logger.warning("Welcome images document doesn't exist", service: "WelcomeImageService")
                self.images = []
                self.cache = []
                self.lastFetchTime = Date()
                isLoading = false
                return
            }
            
            // Parse images array
            if let imagesArray = data["images"] as? [[String: Any]] {
                let parsedImages = imagesArray.compactMap { imageData -> WelcomeImage? in
                    guard let id = imageData["id"] as? String,
                          let url = imageData["url"] as? String else {
                        return nil
                    }
                    
                    let order = imageData["order"] as? Int ?? 0
                    let uploadedAt = (imageData["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    return WelcomeImage(
                        id: id,
                        url: url,
                        order: order,
                        uploadedAt: uploadedAt
                    )
                }
                
                // Sort by order
                let sortedImages = parsedImages.sorted { $0.order < $1.order }
                
                self.images = sortedImages
                self.cache = sortedImages
                self.lastFetchTime = Date()
                
                Logger.info("Fetched \(sortedImages.count) welcome images", service: "WelcomeImageService")
            } else {
                Logger.warning("No images array found in welcome images document", service: "WelcomeImageService")
                self.images = []
                self.cache = []
                self.lastFetchTime = Date()
            }
        } catch {
            Logger.error("Failed to fetch welcome images: \(error.localizedDescription)", service: "WelcomeImageService")
            self.error = error
            // Use cache if available
            if !cache.isEmpty {
                self.images = cache
            }
        }
        
        isLoading = false
    }
    
    /// Clear cache and force refresh
    func refresh() async {
        cache = []
        lastFetchTime = nil
        await fetchImages()
    }
    
    /// Preload all welcome images into Kingfisher cache
    /// This ensures images are ready before the welcome screen appears
    func preloadImages() async {
        // First, make sure we have the image URLs
        if images.isEmpty {
            await fetchImages()
        }
        
        // Preload all images using Kingfisher
        let urls = images.compactMap { URL(string: $0.url) }
        
        guard !urls.isEmpty else {
            Logger.info("No images to preload", service: "WelcomeImageService")
            return
        }
        
        Logger.info("Preloading \(urls.count) welcome images", service: "WelcomeImageService")
        
        // Use Kingfisher's prefetcher to preload images
        let resources = urls.map { KF.ImageResource(downloadURL: $0) }
        let prefetcher = ImagePrefetcher(
            resources: resources,
            options: [
                .diskCacheExpiration(.days(7)),
                .memoryCacheExpiration(.seconds(300))
            ]
        )
        
        // Prefetch images - this will cache them in the background
        // The completion handler provides status but we don't need to wait for it
        prefetcher.start()
        
        // Wait a bit to allow prefetching to start, but don't block the UI
        // The images will be cached and ready when the welcome screen appears
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        Logger.info("Welcome images prefetch started", service: "WelcomeImageService")
    }
}

/// Model for welcome screen image
struct WelcomeImage: Identifiable, Codable {
    let id: String
    let url: String
    let order: Int
    let uploadedAt: Date
}




