//
//  Notification.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/7/25.
//

import Foundation
import FirebaseFirestore

struct Notification: Identifiable {
    var id: String?
    let type: NotificationType
    let message: String
    let actors: [ActorInfo]
    let actorCount: Int
    let targetId: String
    let activityId: String?
    let isRead: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastActivityAt: Date
    let postImageUrl: String?
    let postThumbnailUrl: String?
    let postCaption: String?
    let metadata: [String: Any]?
    
    enum NotificationType: String, Codable, CaseIterable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
        case mention = "mention"
        
        var displayName: String {
            switch self {
            case .like: return "liked"
            case .comment: return "commented on"
            case .follow: return "started following you"
            case .mention: return "mentioned you in"
            }
        }
    }
    
    struct ActorInfo: Codable {
        let id: String
        let username: String
        let profilePhotoUrl: String?
    }
    
    /// Create Notification from Firestore document
    static func from(document: QueryDocumentSnapshot) -> Notification? {
        let data = document.data()
        
        guard let typeString = data["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let message = data["message"] as? String,
              let targetId = data["targetId"] as? String,
              let isRead = data["isRead"] as? Bool,
              let actorCount = data["actorCount"] as? Int else {
            return nil
        }
        
        // Parse actors array
        var actors: [ActorInfo] = []
        if let actorsArray = data["actors"] as? [[String: Any]] {
            for actorData in actorsArray {
                if let id = actorData["id"] as? String,
                   let username = actorData["username"] as? String {
                    let profilePhotoUrl = actorData["profilePhotoUrl"] as? String
                    actors.append(ActorInfo(
                        id: id,
                        username: username,
                        profilePhotoUrl: profilePhotoUrl
                    ))
                }
            }
        }
        
        // Parse timestamps
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastActivityAt = (data["lastActivityAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse optional fields
        let activityId = data["activityId"] as? String
        let postImageUrl = data["postImageUrl"] as? String
        let postThumbnailUrl = data["postThumbnailUrl"] as? String
        let postCaption = data["postCaption"] as? String
        let metadata = data["metadata"] as? [String: Any]
        
        return Notification(
            id: document.documentID,
            type: type,
            message: message,
            actors: actors,
            actorCount: actorCount,
            targetId: targetId,
            activityId: activityId,
            isRead: isRead,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastActivityAt: lastActivityAt,
            postImageUrl: postImageUrl,
            postThumbnailUrl: postThumbnailUrl,
            postCaption: postCaption,
            metadata: metadata
        )
    }
}

// Codable support for metadata
extension Notification {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case message
        case actors
        case actorCount
        case targetId
        case activityId
        case isRead
        case createdAt
        case updatedAt
        case lastActivityAt
        case postImageUrl
        case postThumbnailUrl
        case postCaption
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        type = try container.decode(NotificationType.self, forKey: .type)
        message = try container.decode(String.self, forKey: .message)
        actors = try container.decode([ActorInfo].self, forKey: .actors)
        actorCount = try container.decode(Int.self, forKey: .actorCount)
        targetId = try container.decode(String.self, forKey: .targetId)
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastActivityAt = try container.decode(Date.self, forKey: .lastActivityAt)
        postImageUrl = try container.decodeIfPresent(String.self, forKey: .postImageUrl)
        postThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .postThumbnailUrl)
        postCaption = try container.decodeIfPresent(String.self, forKey: .postCaption)
        
        // Metadata is a dictionary, decode it manually
        if let metadataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .metadata) {
            var metadataDict: [String: Any] = [:]
            for key in metadataContainer.allKeys {
                if let stringValue = try? metadataContainer.decode(String.self, forKey: key) {
                    metadataDict[key.stringValue] = stringValue
                } else if let intValue = try? metadataContainer.decode(Int.self, forKey: key) {
                    metadataDict[key.stringValue] = intValue
                } else if let boolValue = try? metadataContainer.decode(Bool.self, forKey: key) {
                    metadataDict[key.stringValue] = boolValue
                }
            }
            metadata = metadataDict.isEmpty ? nil : metadataDict
        } else {
            metadata = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(message, forKey: .message)
        try container.encode(actors, forKey: .actors)
        try container.encode(actorCount, forKey: .actorCount)
        try container.encode(targetId, forKey: .targetId)
        try container.encodeIfPresent(activityId, forKey: .activityId)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(lastActivityAt, forKey: .lastActivityAt)
        try container.encodeIfPresent(postImageUrl, forKey: .postImageUrl)
        try container.encodeIfPresent(postThumbnailUrl, forKey: .postThumbnailUrl)
        try container.encodeIfPresent(postCaption, forKey: .postCaption)
        
        // Metadata encoding is handled separately when needed
        // For Firestore updates, we'll update fields directly
    }
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

