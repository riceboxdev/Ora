//
//  PageableTests.swift
//  PageableKitTests
//
//  Basic tests for the pagination system
//

import XCTest
@testable import PageableKit

final class PageableTests: XCTestCase {
    
    func testPageInfoInitial() {
        let pageInfo = PageInfo<String>.initial(hasNextPage: true)
        XCTAssertNil(pageInfo.endCursor)
        XCTAssertTrue(pageInfo.hasNextPage)
        
        let noMorePages = PageInfo<String>.initial(hasNextPage: false)
        XCTAssertNil(noMorePages.endCursor)
        XCTAssertFalse(noMorePages.hasNextPage)
    }
    
    func testPageInfoWithCursor() {
        let cursor = "cursor123"
        let pageInfo = PageInfo.withCursor(cursor, hasNextPage: true)
        XCTAssertEqual(pageInfo.endCursor, cursor)
        XCTAssertTrue(pageInfo.hasNextPage)
        
        let noMorePages = PageInfo.withCursor(cursor, hasNextPage: false)
        XCTAssertEqual(noMorePages.endCursor, cursor)
        XCTAssertFalse(noMorePages.hasNextPage)
    }
    
    func testPageInfoWithNilCursor() {
        let pageInfo = PageInfo.withCursor(nil as String?, hasNextPage: true)
        XCTAssertNil(pageInfo.endCursor)
        XCTAssertTrue(pageInfo.hasNextPage)
    }
    
    func testPageableProtocol() async throws {
        struct TestItem: Identifiable, Hashable {
            let id: String
            let value: Int
        }
        
        struct TestPageable: Pageable {
            typealias Value = TestItem
            typealias Cursor = String
            
            private let items: [TestItem]
            
            init(items: [TestItem]) {
                self.items = items
            }
            
            func loadPage(pageInfo: PageInfo<String>?, size: Int) async throws -> (values: [TestItem], pageInfo: PageInfo<String>) {
                let startIndex = pageInfo?.endCursor.flatMap { Int($0) } ?? 0
                let endIndex = min(startIndex + size, items.count)
                let pageItems = Array(items[startIndex..<endIndex])
                
                let hasNextPage = endIndex < items.count
                let nextCursor = endIndex < items.count ? String(endIndex) : nil
                
                let newPageInfo = PageInfo.withCursor(nextCursor, hasNextPage: hasNextPage)
                return (pageItems, newPageInfo)
            }
        }
        
        let allItems = (0..<25).map { TestItem(id: "\($0)", value: $0) }
        let pageable = TestPageable(items: allItems)
        
        // Test initial load
        let (firstPage, firstPageInfo) = try await pageable.loadPage(pageInfo: nil, size: 10)
        XCTAssertEqual(firstPage.count, 10)
        XCTAssertTrue(firstPageInfo.hasNextPage)
        XCTAssertEqual(firstPageInfo.endCursor, "10")
        
        // Test second page
        let (secondPage, secondPageInfo) = try await pageable.loadPage(pageInfo: firstPageInfo, size: 10)
        XCTAssertEqual(secondPage.count, 10)
        XCTAssertTrue(secondPageInfo.hasNextPage)
        XCTAssertEqual(secondPageInfo.endCursor, "20")
        
        // Test last page
        let (thirdPage, thirdPageInfo) = try await pageable.loadPage(pageInfo: secondPageInfo, size: 10)
        XCTAssertEqual(thirdPage.count, 5)
        XCTAssertFalse(thirdPageInfo.hasNextPage)
        XCTAssertEqual(thirdPageInfo.endCursor, "25")
    }
}

