//
//  ModerationStatus.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation

/// Represents the moderation state of a post
enum ModerationStatus: String, Codable, Equatable, CaseIterable {
    /// Post is awaiting moderation review
    case pending
    
    /// Post has been approved and is visible to users
    case approved
    
    /// Post has been rejected and is hidden from users
    case rejected
    
    /// Post has been flagged for admin attention
    case flagged
    
    /// User-friendly display name for the status
    var displayName: String {
        switch self {
        case .pending:
            return "Pending Review"
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        case .flagged:
            return "Flagged"
        }
    }
    
    /// Description of what this status means
    var description: String {
        switch self {
        case .pending:
            return "This post is awaiting moderation review"
        case .approved:
            return "This post has been approved and is visible"
        case .rejected:
            return "This post has been rejected and is hidden"
        case .flagged:
            return "This post has been flagged for admin review"
        }
    }
    
    /// Whether posts with this status should be visible to regular users
    var isVisibleToUsers: Bool {
        switch self {
        case .approved:
            return true
        case .pending, .rejected, .flagged:
            return false
        }
    }
}
