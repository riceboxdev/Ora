//
//  AlgoliaInsightsService.swift
//  OraBeta
//
//  Created for Algolia Events API integration using REST API
//  Documentation: https://www.algolia.com/doc/rest-api/insights
//

import Foundation
import FirebaseAuth

/// Service to track user events for Algolia Personalization API using REST API
/// Documentation: https://www.algolia.com/doc/rest-api/insights
@MainActor
class AlgoliaInsightsService {
    static let shared = AlgoliaInsightsService()
    
    private var isInitialized = false
    private let baseURL = "https://insights.algolia.io"
    private let session = URLSession.shared
    
    private init() {
        // Register service with logging system
        _ = LoggingServiceRegistry.shared.register(serviceName: "AlgoliaInsightsService")
        Logger.info("Initializing", service: "AlgoliaInsightsService")
    }
    
    /// Initialize the Algolia Insights client
    /// Should be called once when the app starts or user logs in
    func initialize() {
        guard !isInitialized else { return }
        
        // Check if credentials are configured
        guard Config.algoliaApplicationID != "YOUR_ALGOLIA_APP_ID",
              Config.algoliaAPIKey != "YOUR_ALGOLIA_API_KEY" else {
            Logger.warning("Algolia credentials not configured. Please update Config.swift", service: "AlgoliaInsightsService")
            return
        }
        
        isInitialized = true
        Logger.info("Initialized successfully", service: "AlgoliaInsightsService")
    }
    
    /// Get the current user token for event tracking
    /// Returns the user's Firebase UID as the userToken for Algolia events
    /// This enables user-level tracking for Analytics, NeuralSearch, and Personalization
    /// Documentation: https://www.algolia.com/doc/api-reference/api-parameters/userToken
    private func getUserToken() -> String? {
        guard let uid = Auth.auth().currentUser?.uid else {
            Logger.warning("No user token available - user not authenticated", service: "AlgoliaInsightsService")
            return nil
        }
        return uid
    }
    
    /// Create HTTP request for Algolia Insights API
    private func createRequest(endpoint: String, body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AlgoliaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.algoliaApplicationID, forHTTPHeaderField: "x-algolia-application-id")
        request.setValue(Config.algoliaAPIKey, forHTTPHeaderField: "x-algolia-api-key")
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        return request
    }
    
    /// Send events to Algolia Insights API
    private func sendEvents(events: [[String: Any]]) async throws {
        guard isInitialized else {
            throw AlgoliaError.notInitialized
        }
        
        let body: [String: Any] = [
            "events": events
        ]
        
        let request = try createRequest(endpoint: "/1/events", body: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlgoliaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("API error (status \(httpResponse.statusCode)): \(errorMessage)", service: "AlgoliaInsightsService")
            throw AlgoliaError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    /// Track a view event - when a user views a post
    /// - Parameters:
    ///   - objectID: The Algolia object ID (typically the post ID)
    ///   Note: Algolia does not support positions for view events (only for click events)
    ///   Note: userToken (user ID) is automatically included in all events
    func trackView(objectID: String) async {
        guard isInitialized else {
            Logger.warning("Cannot track view - service not initialized", service: "AlgoliaInsightsService")
            return
        }
        
        guard let userToken = getUserToken() else {
            Logger.warning("Cannot track view - no user token available", service: "AlgoliaInsightsService")
            return
        }
        
        Logger.debug("Tracking view for objectID: \(objectID)", service: "AlgoliaInsightsService")
        
        let event: [String: Any] = [
            "eventType": "view",
            "eventName": "View",
            "index": Config.algoliaIndexName,
            "userToken": userToken, // User ID for event matching and personalization
            "objectIDs": [objectID],
            "timestamp": Int64(Date().timeIntervalSince1970)
        ]
        
        do {
            try await sendEvents(events: [event])
            Logger.info("Tracked view for objectID: \(objectID) with userToken: \(userToken)", service: "AlgoliaInsightsService")
        } catch {
            Logger.warning("Failed to track view: \(error.localizedDescription)", service: "AlgoliaInsightsService")
        }
    }
    
    /// Track a click event - when a user clicks/taps on a post
    /// - Parameters:
    ///   - objectID: The Algolia object ID (typically the post ID)
    ///   - position: Position in the list where the post was clicked (only included if queryID is provided)
    ///   - queryID: Optional query ID if this was from a search result
    ///   Note: Algolia requires queryID when positions are included in click events
    ///   Note: userToken (user ID) is automatically included in all events
    func trackClick(objectID: String, position: Int? = nil, queryID: String? = nil) async {
        guard isInitialized else {
            Logger.warning("Cannot track click - service not initialized", service: "AlgoliaInsightsService")
            return
        }
        
        guard let userToken = getUserToken() else {
            Logger.warning("Cannot track click - no user token available", service: "AlgoliaInsightsService")
            return
        }
        
        Logger.debug("Tracking click for objectID: \(objectID)", service: "AlgoliaInsightsService")
        if let queryID = queryID {
            Logger.debug("   QueryID: \(queryID)", service: "AlgoliaInsightsService")
        }
        if let position = position {
            Logger.debug("   Position: \(position)", service: "AlgoliaInsightsService")
        }
        
        var event: [String: Any] = [
            "eventType": "click",
            "eventName": "Click",
            "index": Config.algoliaIndexName,
            "userToken": userToken, // User ID for event matching and personalization
            "objectIDs": [objectID],
            "timestamp": Int64(Date().timeIntervalSince1970)
        ]
        
        // Algolia requires queryID when positions are included
        // Only include position if we have a queryID
        if let queryID = queryID {
            event["queryID"] = queryID
            if let position = position {
                event["positions"] = [position]
            }
        }
        // If no queryID, don't include position (positions are only meaningful in search contexts)
        
        do {
            try await sendEvents(events: [event])
            Logger.info("Tracked click for objectID: \(objectID) with userToken: \(userToken)", service: "AlgoliaInsightsService")
        } catch {
            Logger.warning("Failed to track click: \(error.localizedDescription)", service: "AlgoliaInsightsService")
        }
    }
    
    /// Track a conversion event - when a user performs an action (like, save, comment)
    /// - Parameters:
    ///   - objectID: The Algolia object ID (typically the post ID)
    ///   - eventName: Name of the conversion event (e.g., "Post Liked", "Post Saved", "Post Commented")
    ///   - queryID: Optional query ID if this was from a search result
    ///   Note: userToken (user ID) is automatically included in all events
    func trackConversion(objectID: String, eventName: String, queryID: String? = nil) async {
        guard isInitialized else {
            Logger.warning("Cannot track conversion - service not initialized", service: "AlgoliaInsightsService")
            return
        }
        
        guard let userToken = getUserToken() else {
            Logger.warning("Cannot track conversion - no user token available", service: "AlgoliaInsightsService")
            return
        }
        
        Logger.debug("Tracking conversion '\(eventName)' for objectID: \(objectID)", service: "AlgoliaInsightsService")
        
        var event: [String: Any] = [
            "eventType": "conversion",
            "eventName": eventName,
            "index": Config.algoliaIndexName,
            "userToken": userToken, // User ID for event matching and personalization
            "objectIDs": [objectID],
            "timestamp": Int64(Date().timeIntervalSince1970)
        ]
        
        if let queryID = queryID {
            event["queryID"] = queryID
        }
        
        do {
            try await sendEvents(events: [event])
            Logger.info("Tracked conversion '\(eventName)' for objectID: \(objectID) with userToken: \(userToken)", service: "AlgoliaInsightsService")
        } catch {
            Logger.warning("Failed to track conversion: \(error.localizedDescription)", service: "AlgoliaInsightsService")
        }
    }
    
    /// Track a like event (conversion)
    func trackLike(objectID: String) async {
        await trackConversion(objectID: objectID, eventName: "Post Liked")
    }
    
    /// Track a save event (conversion)
    func trackSave(objectID: String) async {
        await trackConversion(objectID: objectID, eventName: "Post Saved")
    }
    
    /// Track a comment event (conversion)
    func trackComment(objectID: String) async {
        await trackConversion(objectID: objectID, eventName: "Post Commented")
    }
    
    /// Track a share event (conversion)
    func trackShare(objectID: String) async {
        await trackConversion(objectID: objectID, eventName: "Post Shared")
    }
    
    /// Track multiple events in a single batch
    /// - Parameter events: Array of event dictionaries
    ///   Note: Each event should include a "userToken" field with the user's ID
    ///   If userToken is missing, events will still be sent but won't be matched to users
    func trackEvents(_ events: [[String: Any]]) async {
        guard isInitialized else {
            Logger.warning("Cannot track events - service not initialized", service: "AlgoliaInsightsService")
            return
        }
        
        // Validate that events include userToken (warn if missing but don't block)
        let eventsWithToken = events.filter { $0["userToken"] != nil }
        if eventsWithToken.count < events.count {
            Logger.warning("Some events are missing userToken - they won't be matched to users", service: "AlgoliaInsightsService")
        }
        
        Logger.debug("Tracking \(events.count) events", service: "AlgoliaInsightsService")
        
        do {
            try await sendEvents(events: events)
            Logger.info("Tracked \(events.count) events", service: "AlgoliaInsightsService")
        } catch {
            Logger.warning("Failed to track events: \(error.localizedDescription)", service: "AlgoliaInsightsService")
        }
    }
}

/// Algolia Insights API errors
enum AlgoliaError: LocalizedError {
    case notInitialized
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Algolia Insights service not initialized"
        case .invalidURL:
            return "Invalid Algolia API URL"
        case .invalidResponse:
            return "Invalid response from Algolia API"
        case .apiError(let statusCode, let message):
            return "Algolia API error (\(statusCode)): \(message)"
        }
    }
}
