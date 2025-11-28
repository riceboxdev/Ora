//
//  BoardService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

@MainActor
class BoardService {
    private let db = Firestore.firestore()
    private let boardsCollection = "boards"
    private let boardPostsCollection = "board_posts"
    
    init() {
    }
    
    /// Create a new board
    func createBoard(_ board: Board) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid,
              userId == board.userId else {
            throw BoardError.unauthorized
        }
        
        // Create board in Firestore
        let docRef = try await db.collection(boardsCollection).addDocument(from: board)
        let boardId = docRef.documentID
        
        print("✅ BoardService: Board created in Firestore: \(boardId)")
        return boardId
    }
    
    /// Get user's boards
    func getUserBoards(userId: String) async throws -> [Board] {
        let snapshot = try await db.collection(boardsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Board.self)
        }
    }
    
    /// Get board by ID
    func getBoard(boardId: String) async throws -> Board? {
        let doc = try await db.collection(boardsCollection).document(boardId).getDocument()
        return try doc.data(as: Board.self)
    }
    
    /// Update board
    func updateBoard(_ board: Board) async throws {
        guard let boardId = board.id,
              let userId = Auth.auth().currentUser?.uid,
              userId == board.userId else {
            throw BoardError.unauthorized
        }
        
        try db.collection(boardsCollection).document(boardId).setData(from: board, merge: true)
    }
    
    /// Delete board
    func deleteBoard(boardId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let board = try await getBoard(boardId: boardId),
              userId == board.userId else {
            throw BoardError.unauthorized
        }
        
        // Delete all board_posts for this board
        let boardPostsSnapshot = try await db.collection(boardPostsCollection)
            .whereField("boardId", isEqualTo: boardId)
            .getDocuments()
        
        for doc in boardPostsSnapshot.documents {
            try await doc.reference.delete()
        }
        
        // Delete board from Firestore
        try await db.collection(boardsCollection).document(boardId).delete()
        
        print("✅ BoardService: Board and all associated posts deleted: \(boardId)")
    }
    
    /// Save post to board
    func savePostToBoard(postId: String, boardId: String, userId: String, postImageUrl: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == userId else {
            throw BoardError.unauthorized
        }
        
        // Check if post is already in board
        let boardPostId = "\(boardId)_\(postId)"
        let boardPostDoc = try await db.collection(boardPostsCollection).document(boardPostId).getDocument()
        
        if boardPostDoc.exists {
            print("ℹ️ BoardService: Post \(postId) already in board \(boardId)")
            return
        }
        
        // Create board_posts document
        try await db.collection(boardPostsCollection).document(boardPostId).setData([
            "boardId": boardId,
            "postId": postId,
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ BoardService: Post \(postId) added to board \(boardId)")
        
        // Update board post count and set cover image if needed
        if var board = try await getBoard(boardId: boardId) {
            board.postCount += 1
            
            // Set cover image if board doesn't have one and post has an image
            if board.coverImageUrl == nil || board.coverImageUrl?.isEmpty == true,
               let imageUrl = postImageUrl, !imageUrl.isEmpty {
                board.coverImageUrl = imageUrl
                print("✅ BoardService: Set cover image for board \(boardId) from first post")
            }
            
            try await updateBoard(board)
        }
        
        // Update post save count (non-blocking)
        Task {
            do {
                try await updatePostSaveCount(postId: postId)
            } catch {
                print("⚠️ BoardService: Failed to update post save count: \(error.localizedDescription)")
            }
        }
        
        // Update user preferences (non-blocking)
        Task {
            do {
                let preferenceService = UserPreferenceService()
                try await preferenceService.updatePreferencesFromEngagement(
                    postId: postId,
                    engagementType: .save
                )
            } catch {
                print("⚠️ BoardService: Failed to update preferences: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if a post is already in a board
    /// - Parameters:
    ///   - postId: The post ID to check
    ///   - boardId: The board ID to check
    /// - Returns: True if the post is in the board, false otherwise
    func isPostInBoard(postId: String, boardId: String) async throws -> Bool {
        let boardPostId = "\(boardId)_\(postId)"
        let boardPostDoc = try await db.collection(boardPostsCollection).document(boardPostId).getDocument()
        return boardPostDoc.exists
    }
    
    /// Check which boards contain a specific post (batch check for multiple boards)
    /// - Parameters:
    ///   - postId: The post ID to check
    ///   - boardIds: Array of board IDs to check
    /// - Returns: Set of board IDs that contain the post
    func getBoardsContainingPost(postId: String, boardIds: [String]) async throws -> Set<String> {
        guard !boardIds.isEmpty else { return [] }
        
        var containingBoardIds: Set<String> = []
        
        // Batch check all boards in parallel
        await withTaskGroup(of: (String, Bool).self) { group in
            for boardId in boardIds {
                group.addTask {
                    do {
                        let isInBoard = try await self.isPostInBoard(postId: postId, boardId: boardId)
                        return (boardId, isInBoard)
                    } catch {
                        print("⚠️ BoardService: Error checking if post is in board \(boardId): \(error.localizedDescription)")
                        return (boardId, false)
                    }
                }
            }
            
            for await (boardId, isInBoard) in group {
                if isInBoard {
                    containingBoardIds.insert(boardId)
                }
            }
        }
        
        return containingBoardIds
    }
    
    /// Remove post from board
    func removePostFromBoard(postId: String, boardId: String, userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == userId else {
            throw BoardError.unauthorized
        }
        
        // Delete board_posts document
        let boardPostId = "\(boardId)_\(postId)"
        let boardPostDoc = try await db.collection(boardPostsCollection).document(boardPostId).getDocument()
        
        guard boardPostDoc.exists else {
            print("ℹ️ BoardService: Post \(postId) not in board \(boardId)")
            return
        }
        
        try await db.collection(boardPostsCollection).document(boardPostId).delete()
        
        print("✅ BoardService: Post \(postId) removed from board \(boardId)")
        
        // Update post save count (non-blocking)
        Task {
            do {
                try await updatePostSaveCount(postId: postId)
            } catch {
                print("⚠️ BoardService: Failed to update post save count: \(error.localizedDescription)")
            }
        }
        
        // Update board post count
        if var board = try await getBoard(boardId: boardId) {
            board.postCount = max(0, board.postCount - 1)
            try await updateBoard(board)
        }
    }
    
    /// Update post save count by counting board_posts
    private func updatePostSaveCount(postId: String) async throws {
        let snapshot = try await db.collection(boardPostsCollection)
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        let saveCount = snapshot.documents.count
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "saveCount": saveCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ BoardService: Updated save count for post \(postId): \(saveCount)")
    }
    
    /// Get posts in a board from Firestore
    func getBoardPosts(boardId: String, limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw BoardError.unauthorized
        }
        
        // Get board_posts documents
        // Note: Firestore doesn't support offset directly, so we fetch more and slice
        let fetchLimit = limit + offset
        let boardPostsSnapshot = try await db.collection(boardPostsCollection)
            .whereField("boardId", isEqualTo: boardId)
            .order(by: "createdAt", descending: true)
            .limit(to: fetchLimit)
            .getDocuments()
        
        // Apply offset by slicing the results
        let allPostIds = boardPostsSnapshot.documents.compactMap { doc -> String? in
            doc.data()["postId"] as? String
        }
        
        // Apply offset
        let postIds = Array(allPostIds.dropFirst(offset).prefix(limit))
        
        guard !postIds.isEmpty else {
            return []
        }
        
        // Fetch posts from Firestore
        var posts: [Post] = []
        
        // First, fetch all post documents
        var postData: [(String, [String: Any])] = []
        await withTaskGroup(of: (String, [String: Any]?).self) { group in
            for postId in postIds {
                group.addTask {
                    do {
                        let doc = try await self.db.collection("posts").document(postId).getDocument()
                        guard doc.exists, let data = doc.data() else {
                            return (postId, nil)
                        }
                        return (postId, data)
                    } catch {
                        print("⚠️ BoardService: Error fetching post \(postId): \(error.localizedDescription)")
                        return (postId, nil)
                    }
                }
            }
            
            for await (postId, data) in group {
                if let data = data {
                    postData.append((postId, data))
                }
            }
        }
        
        // Extract unique user IDs
        var userIds: Set<String> = []
        for (_, data) in postData {
            if let userId = data["userId"] as? String {
                userIds.insert(userId)
            }
        }
        
        // Batch fetch profiles for all unique user IDs
        let profiles: [String: UserProfile]
        if !userIds.isEmpty {
            let profileService = ProfileService()
            do {
                profiles = try await profileService.getUserProfiles(userIds: Array(userIds))
            } catch {
                print("⚠️ BoardService: Failed to batch fetch profiles: \(error.localizedDescription)")
                profiles = [:]
            }
        } else {
            profiles = [:]
        }
        
        // Convert post data to Post objects (using batched profiles)
        for (postId, data) in postData {
            guard let userId = data["userId"] as? String,
                  let imageUrl = data["imageUrl"] as? String else {
                continue
            }
            
            let thumbnailUrl = data["thumbnailUrl"] as? String
            let caption = data["caption"] as? String
            let tags = data["tags"] as? [String]
            let categories = data["categories"] as? [String]
            let imageWidth = data["imageWidth"] as? Int
            let imageHeight = data["imageHeight"] as? Int
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            // Get profile from batched profiles
            let profile = profiles[userId]
            
            let post = Post(
                activityId: postId,
                userId: userId,
                username: profile?.username,
                userProfilePhotoUrl: profile?.profilePhotoUrl,
                imageUrl: imageUrl,
                thumbnailUrl: thumbnailUrl,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                caption: caption,
                tags: tags,
                categories: categories,
                likeCount: 0, // Will be loaded separately if needed
                commentCount: 0, // Will be loaded separately if needed
                viewCount: 0,
                shareCount: 0,
                saveCount: 0,
                createdAt: createdAt
            )
            
            posts.append(post)
        }
        
        // Sort posts to match the order from board_posts
        let postOrder: [String: Int] = Dictionary(uniqueKeysWithValues: postIds.enumerated().map { ($1, $0) })
        posts.sort { post1, post2 in
            let order1 = postOrder[post1.id] ?? Int.max
            let order2 = postOrder[post2.id] ?? Int.max
            return order1 < order2
        }
        
        print("✅ BoardService: Retrieved \(posts.count) posts from board \(boardId)")
        return posts
    }
}

enum BoardError: LocalizedError {
    case unauthorized
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized to perform this action"
        case .notFound:
            return "Board not found"
        }
    }
}

