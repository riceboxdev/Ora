//
//  BlockedUser.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

struct BlockedUser: Codable, Identifiable {
    @DocumentID var id: String?
    var blockerId: String
    var blockedId: String
    var blockedAt: Date
    var reason: String?
    
    init(
        id: String? = nil,
        blockerId: String,
        blockedId: String,
        blockedAt: Date = Date(),
        reason: String? = nil
    ) {
        self.id = id
        self.blockerId = blockerId
        self.blockedId = blockedId
        self.blockedAt = blockedAt
        self.reason = reason
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case blockerId
        case blockedId
        case blockedAt
        case reason
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        blockerId = try container.decode(String.self, forKey: .blockerId)
        blockedId = try container.decode(String.self, forKey: .blockedId)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .blockedAt) {
            blockedAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .blockedAt) {
            blockedAt = date
        } else {
            blockedAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(blockerId, forKey: .blockerId)
        try container.encode(blockedId, forKey: .blockedId)
        try container.encode(Timestamp(date: blockedAt), forKey: .blockedAt)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
}

