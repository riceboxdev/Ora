//
//  PageInfo.swift
//  PageableKit
//
//  Generic page metadata for pagination
//  Similar to Relay's PageInfo but made generic to work with any cursor type
//

import Foundation

/// Generic page metadata for pagination
/// The cursor type can be any type that represents a position in a paginated data source
public struct PageInfo<Cursor> {
    /// The cursor for the current page (represents the position to start the next page)
    public let endCursor: Cursor?
    
    /// Whether there are more pages available
    public let hasNextPage: Bool
    
    /// Create initial page info (no cursor, assumes there might be more)
    /// - Parameter hasNextPage: Whether there are more pages (default: true)
    public static func initial(hasNextPage: Bool = true) -> PageInfo<Cursor> {
        PageInfo(endCursor: nil, hasNextPage: hasNextPage)
    }
    
    /// Create page info from a cursor
    /// - Parameters:
    ///   - cursor: The cursor for this page
    ///   - hasNextPage: Whether there are more pages available
    public static func withCursor(_ cursor: Cursor?, hasNextPage: Bool) -> PageInfo<Cursor> {
        PageInfo(endCursor: cursor, hasNextPage: hasNextPage)
    }
    
    /// Internal initializer
    public init(endCursor: Cursor?, hasNextPage: Bool) {
        self.endCursor = endCursor
        self.hasNextPage = hasNextPage
    }
}



