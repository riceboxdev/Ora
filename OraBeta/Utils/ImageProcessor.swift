//
//  ImageProcessor.swift
//  OraBeta
//
//  Optimized image processing utilities for upload queue
//

import Foundation
import UIKit

actor ImageProcessor {
    static let shared = ImageProcessor()
    
    private init() {}
    
    /// Compress image to JPEG data with optimized quality based on image size
    /// Uses autoreleasepool for memory management
    func compressImage(_ image: UIImage, maxDimension: CGFloat? = nil) -> Data? {
        return autoreleasepool {
            let targetImage: UIImage
            
            // Resize if needed
            if let maxDimension = maxDimension {
                targetImage = resizeImage(image, maxDimension: maxDimension) ?? image
            } else {
                targetImage = image
            }
            
            // Determine compression quality based on image size
            let compressionQuality = determineCompressionQuality(for: targetImage)
            
            // Convert to JPEG
            return targetImage.jpegData(compressionQuality: compressionQuality)
        }
    }
    
    /// Create thumbnail using optimized UIGraphicsImageRenderer
    /// Much faster than preparingThumbnail for large images
    func createThumbnail(_ image: UIImage, maxSize: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        return autoreleasepool {
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            
            // Calculate thumbnail size maintaining aspect ratio
            var thumbnailSize = maxSize
            if aspectRatio > 1 {
                // Landscape
                thumbnailSize.height = maxSize.width / aspectRatio
            } else {
                // Portrait or square
                thumbnailSize.width = maxSize.height * aspectRatio
            }
            
            // Use UIGraphicsImageRenderer for better performance
            let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
            return renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            }
        }
    }
    
    /// Process full image and thumbnail in parallel
    /// Returns both compressed image data and thumbnail data
    func processImage(_ image: UIImage) async -> (fullImageData: Data, thumbnailData: Data, width: Int, height: Int)? {
        // Process full image and thumbnail in parallel using async let
        // Since we're calling actor methods, they will be properly isolated
        async let fullImageDataFuture = compressImage(image)
        async let thumbnailImageFuture = createThumbnail(image)
        
        // Wait for both to complete in parallel
        guard let fullImageData = await fullImageDataFuture,
              let thumbnailImage = await thumbnailImageFuture else {
            return nil
        }
        
        // Compress thumbnail (with max dimension)
        // Note: compressImage is a synchronous actor method, but we're in an async context
        // The actor isolation ensures thread safety
        let thumbnailData = await compressImage(thumbnailImage, maxDimension: 400)
        guard let thumbnailData = thumbnailData else {
            return nil
        }
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        return (fullImageData, thumbnailData, width, height)
    }
    
    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        // If image is already smaller, return as-is
        guard maxSize > maxDimension else {
            return image
        }
        
        // Calculate new size
        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Use UIGraphicsImageRenderer for resizing
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Determine optimal compression quality based on image size
    /// Larger images get more compression to reduce file size
    private func determineCompressionQuality(for image: UIImage) -> CGFloat {
        let megapixels = (image.size.width * image.size.height) / 1_000_000
        
        if megapixels > 12 {
            // Very large images (>12MP): aggressive compression
            return 0.65
        } else if megapixels > 6 {
            // Large images (6-12MP): moderate compression
            return 0.75
        } else {
            // Smaller images (<6MP): high quality
            return 0.85
        }
    }
    
    /// Convert Data back to UIImage (for display purposes)
    /// Should be used sparingly, only when needed for UI
    nonisolated func image(from data: Data) -> UIImage? {
        return UIImage(data: data)
    }
}

