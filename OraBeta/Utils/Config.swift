//
//  Config.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

struct Config {
    // Stream Configuration
    static let streamAPIKey = "8pwvyy4wrvek"
    static let streamAppId = "1445488"
    
    // Firebase Functions
    static let getStreamTokenFunction = "getStreamUserToken"
    
    // Cloudflare Images Configuration
    static let cloudflareAccountId = "9f5f4bb22646ea1c62d1019e99026a66"
    static let cloudflareApiToken = "11HhvRaGba4Xc9hye24x5MOqEy90SMrh"
    static let cloudflareDeliveryUrl = "https://imagedelivery.net/-U9fBlv98S0Bl-wUpX9XJw" // e.g., "https://imagedelivery.net/ACCOUNT_HASH"
    
    // Algolia Configuration
    static let algoliaApplicationID = "AWN7YY6USB"
    static let algoliaAPIKey = "9c69216b2b64fde9412c44ff1a01c672" // API Key for Algolia Search and Recommend
    static let algoliaIndexName = "posts" // Your Algolia index name for posts
    
    // Logging Configuration
    /// App-wide log level. Set to nil to use defaults (full in debug, minimal in release)
    /// To change log level, modify this value:
    /// - .none: No logging
    /// - .minimal: Errors and warnings only
    /// - .full: All logging including debug info
    static var logLevel: LogLevel? = LogLevel.full
    
    /// Per-service log level overrides
    /// Example: ["StreamService": .full, "ImageUploadService": .minimal]
    /// Set to empty dictionary to use app-wide log level for all services
    static var serviceLogLevels: [String: LogLevel] = [:]
    
    /// Per-service logging enabled/disabled states
    /// Set to true to enable logging for a service, false to disable
    /// Example: ["StreamService": true, "ImageSegmentationService": false]
    /// Services not in this dictionary default to enabled
    /// Note: This is the default state - users can override via LoggingServiceRegistry
    static var serviceLoggingStates: [String: Bool] = [:]
}

