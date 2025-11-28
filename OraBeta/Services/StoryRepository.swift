//
//  StoryRepository.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import FirebaseFirestore

class StoryRepository: StoryRepositoryProtocol {
    private let db = Firestore.firestore()
    private let collection = "stories"
    private let logger: StoryLoggingProtocol
    
    init(logger: StoryLoggingProtocol = StoryLogger()) {
        self.logger = logger
    }
    
    func create(_ story: Story) async throws -> Story {
        logger.logDebug("Creating story for user: \(story.userId)", category: "Repository")
        
        do {
            // Generate a new document reference to get the ID
            let docRef = db.collection(collection).document()
            let storyData = try story.toDictionary()
            
            // Debug: Print the story data being sent
            print("🔍 Story data being sent to Firestore: \(storyData)")
            
            try await docRef.setData(storyData)
            logger.logInfo("Story created successfully: \(docRef.documentID)", category: "Repository")
            
            // Create a new story object with the generated ID
            var createdStory = story
            if createdStory.id == nil {
                createdStory.id = docRef.documentID
            }
            
            return createdStory
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.create")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.create")
            throw storyError
        }
    }
    
    func fetchStory(id: String) async throws -> Story? {
        logger.logDebug("Fetching story: \(id)", category: "Repository")
        
        do {
            let document = try await db.collection(collection).document(id).getDocument()
            
            guard document.exists else {
                logger.logInfo("Story not found: \(id)", category: "Repository")
                return nil
            }
            
            let story = try Story(from: document)
            logger.logDebug("Story fetched successfully: \(id)", category: "Repository")
            return story
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.fetchStory")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.fetchStory")
            throw storyError
        }
    }
    
    func fetchStories(for userId: String, limit: Int?, after: Story?) async throws -> [Story] {
        logger.logDebug("Fetching stories for user: \(userId)", category: "Repository")
        print("🔍 StoryRepository.fetchStories called for user: \(userId), limit: \(limit ?? 10)")
        
        do {
            var query: Query = db.collection(collection)
                .whereField("userId", isEqualTo: userId)
                .whereField("expiresAt", isGreaterThan: Date())
                .order(by: "createdAt", descending: true)
                .limit(to: limit ?? 10)
            
            if let after = after, let afterId = after.id {
                let afterDoc = try await db.collection(collection).document(afterId).getDocument()
                query = query.start(afterDocument: afterDoc)
            }
            
            let snapshot = try await query.getDocuments()
            let stories = snapshot.documents.compactMap { document in
                do {
                    return try Story(from: document)
                } catch {
                    print("❌ Error parsing story document: \(error)")
                    return nil
                }
            }
            
            logger.logInfo("Fetched \(stories.count) stories for user: \(userId)", category: "Repository")
            print("🔍 StoryRepository fetched \(stories.count) stories")
            
            return stories
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.fetchStories")
            print("❌ StoryRepository StoryError: \(error)")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.fetchStories")
            print("❌ StoryRepository network error: \(error)")
            throw storyError
        }
    }
    
    func fetchActiveStories(for userIds: [String]) async throws -> [Story] {
        logger.logDebug("Fetching active stories for \(userIds.count) users", category: "Repository")
        
        guard !userIds.isEmpty else { return [] }
        
        do {
            let snapshot = try await db.collection(collection)
                .whereField("userId", in: userIds)
                .whereField("expiresAt", isGreaterThan: Date())
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let stories = snapshot.documents.compactMap { try? Story(from: $0) }
            logger.logInfo("Fetched \(stories.count) active stories", category: "Repository")
            return stories
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.fetchActiveStories")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.fetchActiveStories")
            throw storyError
        }
    }
    
    func update(_ story: Story) async throws -> Story {
        logger.logDebug("Updating story: \(story.id!)", category: "Repository")
        
        do {
            let storyData = try story.toDictionary()
            try await db.collection(collection).document(story.id!).setData(storyData, merge: true)
            
            logger.logInfo("Story updated successfully: \(story.id!)", category: "Repository")
            return story
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.update")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.update")
            throw storyError
        }
    }
    
    func delete(id: String) async throws {
        logger.logDebug("Deleting story: \(id)", category: "Repository")
        
        do {
            try await db.collection(collection).document(id).delete()
            logger.logInfo("Story deleted successfully: \(id)", category: "Repository")
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.delete")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.delete")
            throw storyError
        }
    }
    
    func fetchExpiredStories(before date: Date) async throws -> [Story] {
        logger.logDebug("Fetching expired stories before: \(date)", category: "Repository")
        
        do {
            let snapshot = try await db.collection(collection)
                .whereField("expiresAt", isLessThan: date)
                .getDocuments()
            
            let stories = snapshot.documents.compactMap { try? Story(from: $0) }
            logger.logInfo("Fetched \(stories.count) expired stories", category: "Repository")
            return stories
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.fetchExpiredStories")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.fetchExpiredStories")
            throw storyError
        }
    }
    
    func markAsViewed(storyId: String, userId: String) async throws {
        logger.logDebug("Marking story as viewed: \(storyId) by user: \(userId)", category: "Repository")
        
        do {
            let storyRef = db.collection(collection).document(storyId)
            
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                do {
                    let storyDocument: DocumentSnapshot
                    storyDocument = try transaction.getDocument(storyRef)
                    
                    guard var story = try? Story(from: storyDocument) else {
                        throw StoryError.resourceNotFound("Story")
                    }
                    
                    story.markAsViewed(by: userId)
                    
                    transaction.updateData([
                        "viewers": story.viewers,
                        "viewCount": story.viewCount
                    ], forDocument: storyRef)
                    
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            
            logger.logInfo("Story marked as viewed: \(storyId)", category: "Repository")
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.markAsViewed")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.markAsViewed")
            throw storyError
        }
    }
    
    func storyExists(postId: String, userId: String) async throws -> Bool {
        logger.logDebug("Checking if story exists for post: \(postId), user: \(userId)", category: "Repository")
        
        do {
            // Add timeout to prevent hanging
            let task = Task {
                try await db.collection(collection)
                    .whereField("postId", isEqualTo: postId)
                    .whereField("userId", isEqualTo: userId)
                    .whereField("expiresAt", isGreaterThan: Date())
                    .limit(to: 1)
                    .getDocuments()
            }
            
            let snapshot = try await withThrowingTaskGroup(of: QuerySnapshot.self) { group in
                group.addTask {
                    try await task.value
                }
                
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    throw StoryError.networkError(URLError(.timedOut))
                }
                
                // Return first completed task
                for try await result in group {
                    return result
                }
                
                throw StoryError.networkError(URLError(.timedOut))
            }
            
            let exists = !snapshot.documents.isEmpty
            logger.logDebug("Story exists check result: \(exists)", category: "Repository")
            return exists
        } catch let error as StoryError {
            logger.logError(error, context: "StoryRepository.storyExists")
            throw error
        } catch {
            let storyError = StoryError.networkError(error)
            logger.logError(storyError, context: "StoryRepository.storyExists")
            throw storyError
        }
    }
}
