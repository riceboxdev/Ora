//
//  Announcement.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/26/25.
//

import Foundation
import FirebaseFirestore

struct Announcement: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let pages: [AnnouncementPage]
    let targetAudience: TargetAudience
    let status: AnnouncementStatus
    let createdAt: Date
    let updatedAt: Date
    let createdBy: String
    let version: Int
    
    struct TargetAudience: Codable {
        let type: AudienceType
        let filters: AudienceFilters?
        
        enum AudienceType: String, Codable {
            case all
            case role
            case activity
            case custom
            case segment
        }
        
        struct AudienceFilters: Codable {
            let role: String?
            let days: Int?
            let userIds: [String]?
            let segmentId: String?
        }
    }
    
    enum AnnouncementStatus: String, Codable {
        case draft
        case active
        case archived
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pages
        case targetAudience
        case status
        case createdAt
        case updatedAt
        case createdBy
        case version
    }
    
    init(
        id: String? = nil,
        title: String,
        pages: [AnnouncementPage],
        targetAudience: TargetAudience,
        status: AnnouncementStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.pages = pages
        self.targetAudience = targetAudience
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.version = version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pages = try container.decode([AnnouncementPage].self, forKey: .pages)
        targetAudience = try container.decode(TargetAudience.self, forKey: .targetAudience)
        status = try container.decode(AnnouncementStatus.self, forKey: .status)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        
        // Handle dates - can be Timestamp or Date
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else if let date = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(pages, forKey: .pages)
        try container.encode(targetAudience, forKey: .targetAudience)
        try container.encode(status, forKey: .status)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(Timestamp(date: updatedAt), forKey: .updatedAt)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(version, forKey: .version)
    }
}






