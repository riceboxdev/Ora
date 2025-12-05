//
//  AlgoliaRecommendService.swift
//  OraBeta
//
//  Created for Algolia Recommend API integration using Swift SDK
//  Documentation: https://www.algolia.com/doc/libraries/sdk/methods/recommend/get-recommendations
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Recommend

/// Service to get recommended posts using Algolia Recommend API via Swift SDK
/// Documentation: https://www.algolia.com/doc/libraries/sdk/methods/recommend/get-recommendations
@MainActor
class AlgoliaRecommendService {
    static let shared = AlgoliaRecommendService()
    
    private var recommendClient: RecommendClient?
    private let db = Firestore.firestore()
    private let profileService = ProfileService()
    
    private init() {
        // Register service with logging system
        _ = LoggingServiceRegistry.shared.register(serviceName: "AlgoliaRecommendService")
        Logger.info("Initializing", service: "AlgoliaRecommendService")
        
        // Initialize RecommendClient
        initializeClient()
    }
    
    /// Initialize the Algolia Recommend client
    private func initializeClient() {
        // Check if credentials are configured
        guard Config.algoliaApplicationID != "YOUR_ALGOLIA_APP_ID",
              Config.algoliaAPIKey != "YOUR_ALGOLIA_API_KEY" else {
            Logger.warning("Algolia credentials not configured", service: "AlgoliaRecommendService")
            return
        }
        
        do {
            let client = try RecommendClient(
                appID: Config.algoliaApplicationID,
                apiKey: Config.algoliaAPIKey
            )
            recommendClient = client
            Logger.info("Algolia Recommend client initialized successfully", service: "AlgoliaRecommendService")
        } catch {
            Logger.error("Failed to initialize Algolia Recommend client: \(error.localizedDescription)", service: "AlgoliaRecommendService")
        }
    }
    
    /// Get the RecommendClient, reinitialize if needed
    private func getClient() throws -> RecommendClient {
        if let client = recommendClient {
            return client
        }
        
        // Try to reinitialize if client is nil
        initializeClient()
        
        guard let client = recommendClient else {
            throw AlgoliaRecommendError.notConfigured
        }
        
        return client
    }
    
    /// Get recommended posts based on a source post
    /// - Parameters:
    ///   - objectID: The Algolia object ID of the source post (typically the post ID)
    ///   - limit: Maximum number of recommendations (default: 10)
    ///   - model: Recommendation model to use (default: "related-products")
    /// - Returns: Array of recommended Post objects
    func getRecommendedPosts(
        objectID: String,
        limit: Int = 10,
        model: String = "related-products"
    ) async throws -> [Post] {
        Logger.debug("Requesting recommendations", service: "AlgoliaRecommendService")
        Logger.debug("   ObjectID: \(objectID)", service: "AlgoliaRecommendService")
        Logger.debug("   Model: \(model)", service: "AlgoliaRecommendService")
        Logger.debug("   Limit: \(limit)", service: "AlgoliaRecommendService")
        
        let indexName = Config.algoliaIndexName
        Logger.debug("   Index name: \(indexName)", service: "AlgoliaRecommendService")
        
        // Get the Recommend client
        let client: RecommendClient
        do {
            client = try getClient()
        } catch {
            Logger.warning("Recommend client not available, falling back to Search API", service: "AlgoliaRecommendService")
            Logger.warning("   Error: \(error.localizedDescription)", service: "AlgoliaRecommendService")
            return try await getRecommendedPostsViaSearch(objectID: objectID, limit: limit)
        }
        
        // Build the LookingSimilarQuery request for "Looking Similar" recommendations
        // This model recommends items that look similar based on image attributes
        let lookingSimilarQuery = LookingSimilarQuery(
            indexName: indexName,
            threshold: 0.0, // Minimum score threshold (0 = no threshold)
            maxRecommendations: limit,
            queryParameters: RecommendSearchParams(
                attributesToRetrieve: ["objectID"] // We only need the IDs, will fetch full data from Firestore
            ),
            model: .lookingSimilar,
            objectID: objectID
        )
        
        // Build the GetRecommendationsParams
        let params = GetRecommendationsParams(
            requests: [RecommendationsRequest.lookingSimilarQuery(lookingSimilarQuery)]
        )
        
        // Call the SDK
        do {
            let response = try await client.getRecommendations(getRecommendationsParams: params)
            
            // Extract results from the response
            let results = response.results
            guard !results.isEmpty,
                  let firstResult = results.first else {
                Logger.warning("No recommendations found in response", service: "AlgoliaRecommendService")
                return []
            }
            
            let hits = firstResult.hits
            guard !hits.isEmpty else {
                Logger.warning("No recommendation hits found in response", service: "AlgoliaRecommendService")
                return []
            }
            
            // Extract objectIDs from hits
            let objectIDs = hits.compactMap { hit in
                if case .recommendHit(let recommendHit) = hit {
                    return recommendHit.objectID
                }
                return nil
            }
            
            Logger.info("Found \(objectIDs.count) recommendations for post \(objectID)", service: "AlgoliaRecommendService")
            
            // Fetch full post data from Firestore using the objectIDs
            let posts = try await fetchPostsFromFirestore(objectIDs: objectIDs)
            
            return posts
        } catch {
            Logger.error("Failed to get recommendations: \(error.localizedDescription)", service: "AlgoliaRecommendService")
            Logger.error("   Index name used: \(indexName)", service: "AlgoliaRecommendService")
            
            // Check if it's an index not found error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("index does not exist") || errorString.contains("index not found") {
                Logger.warning("Index '\(indexName)' not found for Recommend API", service: "AlgoliaRecommendService")
                Logger.warning("   Note: Search API works with this index, but Recommend API requires:", service: "AlgoliaRecommendService")
                Logger.warning("   1. The index to have recommendation models configured", service: "AlgoliaRecommendService")
                Logger.warning("   2. The 'looking-similar' model to be trained on your index", service: "AlgoliaRecommendService")
                Logger.warning("   3. Your API key to have Recommend API permissions", service: "AlgoliaRecommendService")
                Logger.warning("   To set up recommendations:", service: "AlgoliaRecommendService")
                Logger.warning("   - Go to Algolia Dashboard > Your Index > Recommendations", service: "AlgoliaRecommendService")
                Logger.warning("   - Enable and train the 'Looking Similar' model", service: "AlgoliaRecommendService")
                Logger.warning("   - Ensure your API key has 'recommend' ACL permissions", service: "AlgoliaRecommendService")
            }
            
            // If we get an error, fall back to Search API
            Logger.info("Falling back to Search API with similar items", service: "AlgoliaRecommendService")
            return try await getRecommendedPostsViaSearch(objectID: objectID, limit: limit)
        }
    }
    
    /// Get recommended posts based on user's viewing history (personalized recommendations)
    /// - Parameters:
    ///   - limit: Maximum number of recommendations (default: 10)
    ///   - model: Recommendation model to use (default: "trending-items")
    /// - Returns: Array of recommended Post objects
    func getPersonalizedRecommendations(
        limit: Int = 10,
        model: String = "trending-items"
    ) async throws -> [Post] {
        // Get current user ID for personalization
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AlgoliaRecommendError.notAuthenticated
        }
        
        Logger.debug("Requesting personalized recommendations", service: "AlgoliaRecommendService")
        Logger.debug("   User ID: \(userId)", service: "AlgoliaRecommendService")
        Logger.debug("   Model: \(model)", service: "AlgoliaRecommendService")
        Logger.debug("   Limit: \(limit)", service: "AlgoliaRecommendService")
        
        let indexName = Config.algoliaIndexName
        
        // Get the Recommend client
        let client: RecommendClient
        do {
            client = try getClient()
        } catch {
            Logger.warning("Recommend client not available, falling back to Search API", service: "AlgoliaRecommendService")
            return [] // Can't do personalized recommendations without the API
        }
        
        // Convert model string to TrendingItemsModel enum
        let trendingModel: TrendingItemsModel
        switch model {
        case "trending-items":
            trendingModel = .trendingItems
        default:
            trendingModel = .trendingItems
        }
        
        // Build the TrendingItemsQuery request
        let trendingQuery = TrendingItemsQuery(
            indexName: indexName,
            threshold: 0.0,
            maxRecommendations: limit,
            queryParameters: RecommendSearchParams(
                userToken: userId, // Use user ID for personalization
                attributesToRetrieve: ["objectID"]
            ),
            model: trendingModel
        )
        
        // Build the GetRecommendationsParams
        let params = GetRecommendationsParams(
            requests: [RecommendationsRequest.trendingItemsQuery(trendingQuery)]
        )
        
        // Call the SDK
        do {
            let response = try await client.getRecommendations(getRecommendationsParams: params)
            
            // Extract results from the response
            let results = response.results
            guard !results.isEmpty,
                  let firstResult = results.first else {
                Logger.warning("No personalized recommendations found", service: "AlgoliaRecommendService")
                return []
            }
            
            let hits = firstResult.hits
            guard !hits.isEmpty else {
                Logger.warning("No personalized recommendation hits found", service: "AlgoliaRecommendService")
                return []
            }
            
            // Extract objectIDs from hits
            let objectIDs = hits.compactMap { hit in
                if case .recommendHit(let recommendHit) = hit {
                    return recommendHit.objectID
                }
                return nil
            }
            
            Logger.info("Found \(objectIDs.count) personalized recommendations for user \(userId)", service: "AlgoliaRecommendService")
            
            // Fetch full post data from Firestore using the objectIDs
            let posts = try await fetchPostsFromFirestore(objectIDs: objectIDs)
            
            return posts
        } catch {
            Logger.error("Failed to get personalized recommendations: \(error.localizedDescription)", service: "AlgoliaRecommendService")
            throw AlgoliaRecommendError.apiError(statusCode: 0, message: error.localizedDescription)
        }
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
                    Logger.warning("Failed to fetch profiles: \(error.localizedDescription)", service: "AlgoliaRecommendService")
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
    
    /// Fallback method: Get recommended posts using Search API with similar items
    /// This is used when the Recommend API is not available (e.g., on lower-tier plans)
    private func getRecommendedPostsViaSearch(objectID: String, limit: Int) async throws -> [Post] {
        Logger.info("Using Search API fallback for recommendations (Recommend API not available)", service: "AlgoliaRecommendService")
        
        // Use Algolia Search API to find similar posts
        // First, get the post details to search for similar items
        let db = Firestore.firestore()
        
        // Try to get the post from Firestore to extract searchable attributes
        let postDoc = try? await db.collection("posts").document(objectID).getDocument()
        
        guard let postData = postDoc?.data() else {
            Logger.warning("Could not find post \(objectID) in Firestore for similarity search", service: "AlgoliaRecommendService")
            return []
        }
        
        // Build a search query based on post attributes
        var searchTerms: [String] = []
        
        // Add interestIds if available (new taxonomy system)
        if let interestIds = postData["interestIds"] as? [String] {
            searchTerms.append(contentsOf: interestIds.prefix(3)) // Use top 3 interests
        }
        
        // Fallback: Add tags if available (legacy)
        if searchTerms.isEmpty, let tags = postData["tags"] as? [String] {
            searchTerms.append(contentsOf: tags.prefix(3))
        }
        
        // Fallback: Add categories if available (legacy)
        if searchTerms.isEmpty, let categories = postData["categories"] as? [String] {
            searchTerms.append(contentsOf: categories)
        }
        
        // If we have search terms, use them; otherwise return empty
        guard !searchTerms.isEmpty else {
            Logger.warning("Post has no searchable attributes (tags, categories, or interestIds) for similarity search", service: "AlgoliaRecommendService")
            return []
        }
        
        // Use the first interest/tag/category as the search query
        let searchQuery = searchTerms.first ?? ""
        
        Logger.debug("Searching for similar posts with query: \(searchQuery)", service: "AlgoliaRecommendService")
        
        // Use the existing AlgoliaSearchService to find similar posts
        // Exclude the current post from results
        let searchResult = try await AlgoliaSearchService.shared.searchPosts(
            query: searchQuery,
            limit: limit + 1 // Get one extra to account for filtering out current post
        )
        
        // Filter out the current post
        let recommendedPosts = searchResult.posts.filter { $0.id != objectID }.prefix(limit)
        
        Logger.info("Found \(recommendedPosts.count) similar posts via Search API", service: "AlgoliaRecommendService")
        
        return Array(recommendedPosts)
    }
}

/// Algolia Recommend API errors
enum AlgoliaRecommendError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Algolia credentials not configured. Please update Config.swift"
        case .notAuthenticated:
            return "User not authenticated. Please log in to get personalized recommendations."
        case .invalidURL:
            return "Invalid Algolia API URL"
        case .invalidResponse:
            return "Invalid response from Algolia API"
        case .apiError(let statusCode, let message):
            return "Algolia API error (\(statusCode)): \(message)"
        }
    }
}

