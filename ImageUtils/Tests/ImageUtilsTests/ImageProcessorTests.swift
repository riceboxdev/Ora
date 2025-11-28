//
//  ImageProcessorTests.swift
//  ImageUtilsTests
//
//  Basic tests for the image processor
//

import XCTest
@testable import ImageUtils

@available(iOS 15.0, *)
final class ImageProcessorTests: XCTestCase {
    
    func testCompressImage() async {
        // Create a test image
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let processor = ImageProcessor.shared
        
        // Test compression
        let compressedData = await processor.compressImage(image)
        XCTAssertNotNil(compressedData)
        XCTAssertGreaterThan(compressedData!.count, 0)
    }
    
    func testCompressImageWithMaxDimension() async {
        // Create a large test image
        let size = CGSize(width: 2000, height: 2000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let processor = ImageProcessor.shared
        
        // Test compression with max dimension
        let compressedData = await processor.compressImage(image, maxDimension: 1000)
        XCTAssertNotNil(compressedData)
        
        // Verify the compressed image is smaller
        if let compressedImage = processor.image(from: compressedData!) {
            let maxDimension = max(compressedImage.size.width, compressedImage.size.height)
            XCTAssertLessThanOrEqual(maxDimension, 1000)
        }
    }
    
    func testCreateThumbnail() async {
        // Create a test image
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let processor = ImageProcessor.shared
        
        // Test thumbnail creation
        let thumbnail = await processor.createThumbnail(image)
        XCTAssertNotNil(thumbnail)
        
        // Verify thumbnail size
        if let thumbnail = thumbnail {
            let maxDimension = max(thumbnail.size.width, thumbnail.size.height)
            XCTAssertLessThanOrEqual(maxDimension, 400)
        }
    }
    
    func testCreateThumbnailWithCustomSize() async {
        // Create a test image
        let size = CGSize(width: 1000, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.purple.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let processor = ImageProcessor.shared
        
        // Test thumbnail creation with custom size
        let customSize = CGSize(width: 200, height: 200)
        let thumbnail = await processor.createThumbnail(image, maxSize: customSize)
        XCTAssertNotNil(thumbnail)
        
        // Verify thumbnail size
        if let thumbnail = thumbnail {
            let maxDimension = max(thumbnail.size.width, thumbnail.size.height)
            XCTAssertLessThanOrEqual(maxDimension, 200)
        }
    }
    
    func testProcessImage() async {
        // Create a test image
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let processor = ImageProcessor.shared
        
        // Test full processing
        let processed = await processor.processImage(image)
        XCTAssertNotNil(processed)
        
        if let processed = processed {
            XCTAssertGreaterThan(processed.fullImageData.count, 0)
            XCTAssertGreaterThan(processed.thumbnailData.count, 0)
            XCTAssertEqual(processed.width, 1200)
            XCTAssertEqual(processed.height, 800)
        }
    }
    
    func testImageFromData() {
        // Create a test image
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        // Convert to data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create image data")
            return
        }
        
        let processor = ImageProcessor.shared
        
        // Test conversion back to image
        let convertedImage = processor.image(from: imageData)
        XCTAssertNotNil(convertedImage)
        XCTAssertEqual(convertedImage?.size.width, 100)
        XCTAssertEqual(convertedImage?.size.height, 100)
    }
}



