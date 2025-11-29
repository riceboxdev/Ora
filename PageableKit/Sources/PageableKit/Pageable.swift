//
//  Pageable.swift
//  PageableKit
//
//  Protocol for data sources that support pagination
//  Inspired by the Whatnot Engineering article: https://medium.com/whatnot-engineering/the-next-page-8950875d927a
//

import Foundation

/// Protocol for data sources that support pagination
/// The cursor type represents the position marker for pagination (e.g., document snapshot, offset, token)
public protocol Pageable {
    /// The type of value being paginated (must be Identifiable and Hashable for SwiftUI)
    associatedtype Value: Identifiable & Hashable
    
    /// The type of cursor used for pagination
    associatedtype Cursor
    
    /// Load a page of values
    /// - Parameters:
    ///   - pageInfo: Current page info containing the cursor (endCursor) for pagination
    ///   - size: Number of items to fetch in this page
    /// - Returns: A tuple containing the page of values and updated page info
    func loadPage(pageInfo: PageInfo<Cursor>?, size: Int) async throws -> (values: [Value], pageInfo: PageInfo<Cursor>)
}






