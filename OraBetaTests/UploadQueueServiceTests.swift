//
//  UploadQueueServiceTests.swift
//  OraBetaTests
//

import XCTest
import Combine
import UIKit
@testable import OraBeta

final class UploadQueueServiceTests: XCTestCase {
    func testEnqueuePersists() async throws {
        let service = UploadQueueService.shared
        let initialCount = await MainActor.run { service.items.count }
        
        let image = UIImage(systemName: "photo") ?? UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10)).fill()
        }
        
        // Process image to get compressed data (required for new UploadPayload)
        guard let processed = await ImageProcessor.shared.processImage(image) else {
            XCTFail("Failed to process test image")
            return
        }
        
        let payload = UploadPayload(
            imageData: processed.fullImageData,
            thumbnailData: processed.thumbnailData,
            imageWidth: processed.width,
            imageHeight: processed.height,
            title: "Test",
            description: nil,
            tags: ["a","b","c"],
            categories: ["abstract"]
        )
        
        await MainActor.run {
            service.enqueue([payload])
        }
        
        let finalCount = await MainActor.run { service.items.count }
        XCTAssertEqual(finalCount, initialCount + 1)
    }
}


