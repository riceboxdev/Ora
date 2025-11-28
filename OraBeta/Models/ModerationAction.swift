//
//  ModerationAction.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation
import FirebaseFirestore

/// Represents a moderation action taken on a post (for audit trail)
struct ModerationAction: Identifiable, Codable, Equatable {
    /// Unique identifier for the action
    @DocumentID var id: String?
    
    /// ID of the post this action relates to
    let postId: String
    
    /// User ID of the moderator who took this action
    let moderatorUserId: String
    
    /// The moderation status that was applied
    let action: ModerationStatus
    
    /// Optional reason for the action (especially for rejections/flags)
    let reason: String?
    
    /// Additional notes from the moderator
    let notes: String?
    
    /// Name of the moderation rule that triggered this action (if automated)
    let ruleName: String?
    
    /// When the action was taken
    let timestamp: Date
    
    /// Additional metadata (flexible for rule-specific data)
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case moderatorUserId
        case action
        case reason
        case notes
        case ruleName
        case timestamp
        case metadata
    }
    
    init(
        id: String? = nil,
        postId: String,
        moderatorUserId: String,
        action: ModerationStatus,
        reason: String? = nil,
        notes: String? = nil,
        ruleName: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.postId = postId
        self.moderatorUserId = moderatorUserId
        self.action = action
        self.reason = reason
        self.notes = notes
        self.ruleName = ruleName
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        moderatorUserId = try container.decode(String.self, forKey: .moderatorUserId)
        action = try container.decode(ModerationStatus.self, forKey: .action)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        ruleName = try container.decodeIfPresent(String.self, forKey: .ruleName)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        
        // Handle timestamp - can be Timestamp or Date
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .timestamp) {
            self.timestamp = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .timestamp) {
            self.timestamp = date
        } else {
            self.timestamp = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Don't encode id - managed by Firestore
        try container.encode(postId, forKey: .postId)
        try container.encode(moderatorUserId, forKey: .moderatorUserId)
        try container.encode(action, forKey: .action)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(ruleName, forKey: .ruleName)
        try container.encode(Timestamp(date: timestamp), forKey: .timestamp)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}
