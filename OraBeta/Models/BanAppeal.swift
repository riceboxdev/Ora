//
//  BanAppeal.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

enum BanAppealStatus: String, Codable {
    case pending
    case approved
    case rejected
}

struct BanAppeal: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var reason: String
    var status: BanAppealStatus
    var submittedAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?
    var reviewNotes: String?
    
    init(
        id: String? = nil,
        userId: String,
        reason: String,
        status: BanAppealStatus = .pending,
        submittedAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        reviewNotes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.reason = reason
        self.status = status
        self.submittedAt = submittedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.reviewNotes = reviewNotes
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case reason
        case status
        case submittedAt
        case reviewedAt
        case reviewedBy
        case reviewNotes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        reason = try container.decode(String.self, forKey: .reason)
        status = try container.decode(BanAppealStatus.self, forKey: .status)
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .submittedAt) {
            submittedAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .submittedAt) {
            submittedAt = date
        } else {
            submittedAt = Date()
        }
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .reviewedAt) {
            reviewedAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .reviewedAt) {
            reviewedAt = date
        }
        
        reviewedBy = try container.decodeIfPresent(String.self, forKey: .reviewedBy)
        reviewNotes = try container.decodeIfPresent(String.self, forKey: .reviewNotes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(reason, forKey: .reason)
        try container.encode(status, forKey: .status)
        try container.encode(Timestamp(date: submittedAt), forKey: .submittedAt)
        
        if let reviewedDate = reviewedAt {
            try container.encode(Timestamp(date: reviewedDate), forKey: .reviewedAt)
        }
        
        try container.encodeIfPresent(reviewedBy, forKey: .reviewedBy)
        try container.encodeIfPresent(reviewNotes, forKey: .reviewNotes)
    }
}













