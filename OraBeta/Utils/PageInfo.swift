//
//  PageInfo.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

/// Page metadata for Firestore pagination
/// Similar to Relay's PageInfo but adapted for Firestore cursors
struct PageInfo {
    /// The last document snapshot (cursor) for the current page
    let endCursor: QueryDocumentSnapshot?
    
    /// Whether there are more pages available
    let hasNextPage: Bool
    
    /// Create initial page info (no cursor, assumes there might be more)
    static func initial(hasNextPage: Bool = true) -> PageInfo {
        PageInfo(endCursor: nil, hasNextPage: hasNextPage)
    }
    
    /// Create page info from a cursor
    static func withCursor(_ cursor: QueryDocumentSnapshot?, hasNextPage: Bool) -> PageInfo {
        PageInfo(endCursor: cursor, hasNextPage: hasNextPage)
    }
}






