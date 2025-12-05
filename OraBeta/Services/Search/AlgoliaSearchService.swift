//
//  AlgoliaSearchService.swift
//  OraBeta
//
//  Created for Algolia Search API integration using REST API
//  Documentation: https://www.algolia.com/doc/rest-api/search
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service to search posts using Algolia Search API via REST
/// Documentation: https://www.algolia.com/doc/rest-api/search
@MainActor
class AlgoliaSearchService {
    static let shared = AlgoliaSearchService()
    
    private let baseURL = "https://{APPLICATION_ID}.algolia.net"
    private let session = URLSession.shared
    private let db = Firestore.firestore()
    private let profileService = ProfileService()
    
    private init() {}
    
    /// Search posts using Algolia
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results (default: 20)
    ///   - page: Page number for pagination (default: 0)
    /// - Returns: Search result containing posts and queryID for tracking
    func searchPosts(query: String, limit: Int = 20, page: Int = 0) async throws -> SearchResult {
        guard !query.isEmpty else {
            return SearchResult(posts: [], queryID: nil, nbHits: 0, page: 0, nbPages: 0)
        }
        
        // Check if credentials are configured
        guard Config.algoliaApplicationID != "YOUR_ALGOLIA_APP_ID",
              Config.algoliaAPIKey != "YOUR_ALGOLIA_API_KEY" else {
            throw AlgoliaSearchError.notConfigured
        }
        
        // Build search URL
        let appId = Config.algoliaApplicationID
        let indexName = Config.algoliaIndexName
        let urlString = baseURL
            .replacingOccurrences(of: "{APPLICATION_ID}", with: appId)
            + "/1/indexes/\(indexName)/query"
        
        guard let url = URL(string: urlString) else {
            throw AlgoliaSearchError.invalidURL
        }
        
        // Build request body
        let requestBody: [String: Any] = [
            "query": query,
            "hitsPerPage": limit,
            "page": page,
            "getRankingInfo": true, // Get queryID for click tracking
            "attributesToRetrieve": ["objectID"] // We only need the IDs, will fetch full data from Firestore
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appId, forHTTPHeaderField: "x-algolia-application-id")
        request.setValue(Config.algoliaAPIKey, forHTTPHeaderField: "x-algolia-api-key")
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        // Perform search request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ AlgoliaSearchService: API error (status \(httpResponse.statusCode)): \(errorMessage)")
            throw AlgoliaSearchError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        // Extract queryID for click tracking
        let queryID = json["queryID"] as? String
        
        // Extract hits (search results)
        guard let hits = json["hits"] as? [[String: Any]] else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        // Extract pagination info
        let nbHits = json["nbHits"] as? Int ?? 0
        let currentPage = json["page"] as? Int ?? 0
        let nbPages = json["nbPages"] as? Int ?? 0
        
        // Extract objectIDs from hits
        let objectIDs = hits.compactMap { $0["objectID"] as? String }
        
        print("✅ AlgoliaSearchService: Found \(objectIDs.count) results for query '\(query)'")
        if let queryID = queryID {
            print("   QueryID: \(queryID)")
        }
        
        // Fetch full post data from Firestore using the objectIDs
        let posts = try await fetchPostsFromFirestore(objectIDs: objectIDs)
        
        return SearchResult(
            posts: posts,
            queryID: queryID,
            nbHits: nbHits,
            page: currentPage,
            nbPages: nbPages
        )
    }
    
    /// Fetch full post data from Firestore using objectIDs returned by Algolia
    private func fetchPostsFromFirestore(objectIDs: [String]) async throws -> [Post] {
        guard !objectIDs.isEmpty else {
            return []
        }
        
        // Batch fetch posts from Firestore
        // Note: Firestore 'in' queries are limited to 10 items, so we need to batch
        let batchSize = 10
        var allPosts: [Post] = []
        
        for i in stride(from: 0, to: objectIDs.count, by: batchSize) {
            let batch = Array(objectIDs[i..<min(i + batchSize, objectIDs.count)])
            
            // Query Firestore for posts with these IDs
            // We'll query by activityId (which should match the Algolia objectID)
            let query = db.collection("posts")
                .whereField("activityId", in: batch)
            
            let snapshot = try await query.getDocuments()
            
            // Extract unique user IDs from documents
            var userIds: Set<String> = []
            for document in snapshot.documents {
                let data = document.data()
                if let userId = data["userId"] as? String {
                    userIds.insert(userId)
                }
            }
            
            // Batch fetch profiles for all unique user IDs
            let profiles: [String: UserProfile]
            if !userIds.isEmpty {
                do {
                    profiles = try await profileService.getUserProfiles(userIds: Array(userIds))
                } catch {
                    print("⚠️ AlgoliaSearchService: Failed to fetch profiles: \(error.localizedDescription)")
                    profiles = [:]
                }
            } else {
                profiles = [:]
            }
            
            // Convert Firestore documents to Post objects
            var batchPosts: [Post] = []
            for document in snapshot.documents {
                let data = document.data()
                if let post = await Post.from(firestoreData: data, documentId: document.documentID, profiles: profiles, profileService: profileService) {
                    batchPosts.append(post)
                }
            }
            
            // Maintain the order from Algolia results
            // Create a mapping of activityId to Post
            let postMap = Dictionary(uniqueKeysWithValues: batchPosts.map { ($0.activityId, $0) })
            
            // Add posts in the order they appeared in Algolia results
            for objectID in batch {
                if let post = postMap[objectID] {
                    allPosts.append(post)
                }
            }
        }
        
        return allPosts
    }
    
    /// Search posts by interest ID
    /// - Parameters:
    ///   - interestId: ID of the interest to search for
    ///   - limit: Maximum number of results (default: 20)
    /// - Returns: Array of Post objects matching the interest
    func searchPostsByInterest(
        interestId: String,
        limit: Int = 20
    ) async throws -> [Post] {
        guard !interestId.isEmpty else {
            return []
        }
        
        // Check if credentials are configured
        guard Config.algoliaApplicationID != "YOUR_ALGOLIA_APP_ID",
              Config.algoliaAPIKey != "YOUR_ALGOLIA_API_KEY" else {
            throw AlgoliaSearchError.notConfigured
        }
        
        // Build search URL
        let appId = Config.algoliaApplicationID
        let indexName = Config.algoliaIndexName
        let urlString = baseURL
            .replacingOccurrences(of: "{APPLICATION_ID}", with: appId)
            + "/1/indexes/\(indexName)/query"
        
        guard let url = URL(string: urlString) else {
            throw AlgoliaSearchError.invalidURL
        }
        
        // Build query to search in interestIds array
        let query = "interestIds:\"\(interestId)\""
        
        // Build request body
        let requestBody: [String: Any] = [
            "query": query,
            "hitsPerPage": limit,
            "page": 0,
            "getRankingInfo": false,
            "attributesToRetrieve": ["objectID"] // We only need the IDs, will fetch full data from Firestore
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appId, forHTTPHeaderField: "x-algolia-application-id")
        request.setValue(Config.algoliaAPIKey, forHTTPHeaderField: "x-algolia-api-key")
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        // Perform search request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ AlgoliaSearchService: API error (status \(httpResponse.statusCode)): \(errorMessage)")
            throw AlgoliaSearchError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        // Extract hits (search results)
        guard let hits = json["hits"] as? [[String: Any]] else {
            throw AlgoliaSearchError.invalidResponse
        }
        
        // Extract objectIDs from hits
        let objectIDs = hits.compactMap { $0["objectID"] as? String }
        
        print("✅ AlgoliaSearchService: Found \(objectIDs.count) results for interest '\(interestId)'")
        
        // Fetch full post data from Firestore using the objectIDs
        return try await fetchPostsFromFirestore(objectIDs: objectIDs)
    }
    
    /// Search posts by topic (DEPRECATED - use searchPostsByInterest instead)
    /// Kept for backwards compatibility but should be migrated to interest-based search
    @available(*, deprecated, message: "Use searchPostsByInterest instead")
    func searchPostsByTopic(
        topicName: String,
        topicType: TrendingTopic.TopicType,
        limit: Int = 20
    ) async throws -> [Post] {
        // For backwards compatibility, search by interestId
        // Assuming topic name maps to interest ID (lowercase)
        return try await searchPostsByInterest(interestId: topicName.lowercased(), limit: limit)
    }
}


/// Search result containing posts and metadata
struct SearchResult {
    let posts: [Post]
    let queryID: String? // For click tracking
    let nbHits: Int // Total number of hits
    let page: Int // Current page
    let nbPages: Int // Total number of pages
}

/// Algolia Search API errors
enum AlgoliaSearchError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Algolia credentials not configured. Please update Config.swift"
        case .invalidURL:
            return "Invalid Algolia API URL"
        case .invalidResponse:
            return "Invalid response from Algolia API"
        case .apiError(let statusCode, let message):
            return "Algolia API error (\(statusCode)): \(message)"
        }
    }
}






