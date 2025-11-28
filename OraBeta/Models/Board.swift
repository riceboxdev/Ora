//
//  Board.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

struct Board: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var coverImageUrl: String?
    var isPrivate: Bool
    var userId: String
    var postCount: Int
    var createdAt: Date
    var activityId: String?
    
    var isPublic: Bool {
        return !isPrivate
    }
    
    init(
        id: String? = nil,
        title: String,
        description: String? = nil,
        coverImageUrl: String? = nil,
        isPrivate: Bool = false,
        userId: String,
        postCount: Int = 0,
        createdAt: Date = Date(),
        activityId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.isPrivate = isPrivate
        self.userId = userId
        self.postCount = postCount
        self.createdAt = createdAt
        self.activityId = activityId
    }
}

