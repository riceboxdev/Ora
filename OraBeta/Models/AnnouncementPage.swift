//
//  AnnouncementPage.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/26/25.
//

import Foundation

struct AnnouncementPage: Codable, Identifiable {
    let id: String
    let title: String?
    let body: String
    let imageUrl: String?
    let layout: String? // "default", "centered", "image-top", etc.
    let metadata: [String: AnyCodable]? // Flexible JSON for custom layouts
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case imageUrl
        case layout
        case metadata
    }
    
    init(
        id: String = UUID().uuidString,
        title: String? = nil,
        body: String,
        imageUrl: String? = nil,
        layout: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.layout = layout
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        layout = try container.decodeIfPresent(String.self, forKey: .layout)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(layout, forKey: .layout)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

