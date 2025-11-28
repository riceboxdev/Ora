//
//  TagService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFunctions
import FirebaseAuth
import FirebaseFirestore

@MainActor
class TagService {
    private let functions = Functions.functions()
    private let db = Firestore.firestore()
    
    static let shared = TagService()
    
    private init() {}
    
    /// Get tag suggestions with intelligent fallback hierarchy using direct Firestore queries
    /// - Parameters:
    ///   - query: Partial tag text for filtering
    ///   - postId: Optional post ID for context-aware suggestions
    ///   - semanticLabels: Optional semantic labels for context-aware suggestions
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of tag suggestions with source information
    func getTagSuggestions(
        query: String = "",
        postId: String? = nil,
        semanticLabels: [String] = [],
        limit: Int = 20
    ) async throws -> [TagSuggestion] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw TagError.notAuthenticated
        }
        
        let db = Firestore.firestore()
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var suggestionMap: [String: TagSuggestion] = [:]
        
        // 1. Context-aware suggestions (if semantic labels provided)
        if !semanticLabels.isEmpty {
            do {
                let labelsToQuery = Array(semanticLabels.prefix(3)) // Firestore limit
                let similarPostsSnapshot = try await db.collection("posts")
                    .whereField("semanticLabels", arrayContainsAny: labelsToQuery)
                    .limit(to: 50)
                    .getDocuments()
                
                var tagCounts: [String: Int] = [:]
                for doc in similarPostsSnapshot.documents {
                    let post = doc.data()
                    if let tags = post["tags"] as? [String] {
                        for tag in tags {
                            let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if normalizedQuery.isEmpty || normalizedTag.contains(normalizedQuery) {
                                tagCounts[normalizedTag, default: 0] += 1
                            }
                        }
                    }
                }
                
                // Add context-aware suggestions
                for (tag, count) in tagCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
                    if suggestionMap[tag] == nil {
                        suggestionMap[tag] = TagSuggestion(
                            id: tag,
                            tag: tag,
                            displayName: tag,
                            source: .context,
                            score: Double(count)
                        )
                    }
                }
            } catch {
                print("⚠️ TagService: Failed to get context-aware suggestions: \(error.localizedDescription)")
            }
        }
        
        // 2. User's previous tags
        do {
            let userPostsSnapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .limit(to: 100)
                .getDocuments()
            
            var userTagCounts: [String: Int] = [:]
            for doc in userPostsSnapshot.documents {
                let post = doc.data()
                if let tags = post["tags"] as? [String] {
                    for tag in tags {
                        let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if normalizedQuery.isEmpty || normalizedTag.contains(normalizedQuery) {
                            userTagCounts[normalizedTag, default: 0] += 1
                        }
                    }
                }
            }
            
            // Add user's tags
            for (tag, count) in userTagCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
                if let existing = suggestionMap[tag] {
                    // Boost score if already exists
                    suggestionMap[tag] = TagSuggestion(
                        id: tag,
                        tag: tag,
                        displayName: tag,
                        source: existing.source,
                        score: existing.score + Double(count) * 0.5
                    )
                } else {
                    suggestionMap[tag] = TagSuggestion(
                        id: tag,
                        tag: tag,
                        displayName: tag,
                        source: .user,
                        score: Double(count)
                    )
                }
            }
        } catch {
            print("⚠️ TagService: Failed to get user tags: \(error.localizedDescription)")
        }
        
        // 3. Popular tags (global) - try tags collection first
        do {
            let tagsSnapshot = try await db.collection("tags")
                .order(by: "usageCount", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            if !tagsSnapshot.isEmpty {
                for doc in tagsSnapshot.documents {
                    let tagData = doc.data()
                    guard let tagId = tagData["id"] as? String ?? doc.documentID as String? else { continue }
                    let normalizedTag = tagId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if normalizedQuery.isEmpty || normalizedTag.contains(normalizedQuery) {
                        if suggestionMap[normalizedTag] == nil {
                            let usageCount = tagData["usageCount"] as? Int ?? 0
                            let displayName = tagData["name"] as? String ?? normalizedTag
                            suggestionMap[normalizedTag] = TagSuggestion(
                                id: normalizedTag,
                                tag: normalizedTag,
                                displayName: displayName,
                                source: .popular,
                                score: Double(usageCount)
                            )
                        }
                    }
                }
            }
        } catch {
            print("⚠️ TagService: Tags collection not available or query failed: \(error.localizedDescription)")
        }
        
        // 4. Fallback: Get popular tags from all posts if we don't have enough suggestions
        if suggestionMap.count < 10 {
            do {
                let allPostsSnapshot = try await db.collection("posts")
                    .limit(to: 500)
                    .getDocuments()
                
                var globalTagCounts: [String: Int] = [:]
                for doc in allPostsSnapshot.documents {
                    let post = doc.data()
                    if let tags = post["tags"] as? [String] {
                        for tag in tags {
                            let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if normalizedQuery.isEmpty || normalizedTag.contains(normalizedQuery) {
                                globalTagCounts[normalizedTag, default: 0] += 1
                            }
                        }
                    }
                }
                
                // Add global popular tags
                for (tag, count) in globalTagCounts.sorted(by: { $0.value > $1.value }).prefix(20) {
                    if let existing = suggestionMap[tag] {
                        // Update score if exists
                        if existing.source == .popular {
                            suggestionMap[tag] = TagSuggestion(
                                id: tag,
                                tag: tag,
                                displayName: tag,
                                source: .popular,
                                score: max(existing.score, Double(count))
                            )
                        }
                    } else {
                        suggestionMap[tag] = TagSuggestion(
                            id: tag,
                            tag: tag,
                            displayName: tag,
                            source: .popular,
                            score: Double(count)
                        )
                    }
                }
            } catch {
                print("⚠️ TagService: Failed to get global popular tags from posts: \(error.localizedDescription)")
            }
        }
        
        // Convert to array and sort by priority: context > user > popular, then by score
        var suggestions = Array(suggestionMap.values)
        suggestions.sort { a, b in
            let sourceOrder: [TagSuggestion.SuggestionSource: Int] = [.context: 3, .user: 2, .popular: 1]
            let sourceDiff = (sourceOrder[b.source] ?? 0) - (sourceOrder[a.source] ?? 0)
            if sourceDiff != 0 {
                return sourceDiff > 0
            }
            return b.score > a.score
        }
        
        return Array(suggestions.prefix(limit))
    }
    
    /// Validate tags (1-5 tags required)
    /// - Parameter tags: Array of tag strings
    /// - Returns: Validation result
    func validateTags(_ tags: [String]) async throws -> TagValidationResult {
        let function = functions.httpsCallable("validatePostTags")
        
        let result = try await function.call(["tags": tags])
        
        guard let response = result.data as? [String: Any] else {
            throw TagError.invalidResponse
        }
        
        let valid = response["valid"] as? Bool ?? false
        let error = response["error"] as? String
        
        return TagValidationResult(valid: valid, error: error)
    }
    
    /// Normalize tag text (lowercase, trim)
    /// - Parameter tag: Tag string to normalize
    /// - Returns: Normalized tag
    func normalizeTag(_ tag: String) -> String {
        return tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if user has untagged posts
    /// - Parameter userId: User ID to check
    /// - Returns: True if user has posts without tags
    func hasUntaggedPosts(userId: String) async throws -> Bool {
        // Firestore doesn't support querying for empty arrays directly
        // We'll query posts and check if any have empty or missing tags
        let db = Firestore.firestore()
        let snapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 50) // Check up to 50 posts
            .getDocuments()
        
        // Check if any post has empty or missing tags
        for doc in snapshot.documents {
            let data = doc.data()
            // Check if tags field is missing, null, or empty array
            if !data.keys.contains("tags") {
                return true // No tags field
            }
            if let tags = data["tags"] as? [String], tags.isEmpty {
                return true // Empty tags array
            }
            if data["tags"] == nil {
                return true // Tags is null
            }
        }
        
        return false
    }
}

struct TagSuggestion: Identifiable {
    let id: String
    let tag: String
    let displayName: String
    let source: SuggestionSource
    let score: Double
    
    enum SuggestionSource: String {
        case context
        case user
        case popular
    }
    
    init(id: String, tag: String, displayName: String, source: SuggestionSource, score: Double) {
        self.id = id
        self.tag = tag
        self.displayName = displayName
        self.source = source
        self.score = score
    }
    
    init?(from dictionary: [String: Any]) {
        guard let tag = dictionary["tag"] as? String else {
            return nil
        }
        
        self.id = tag
        self.tag = tag
        self.displayName = dictionary["displayName"] as? String ?? tag
        self.source = SuggestionSource(rawValue: dictionary["source"] as? String ?? "popular") ?? .popular
        self.score = dictionary["score"] as? Double ?? 0.0
    }
}

struct TagValidationResult {
    let valid: Bool
    let error: String?
}

enum TagError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .validationFailed(let message):
            return message
        }
    }
}
