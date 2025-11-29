//
//  FeatureFlagProvider.swift
//  FeatureFlags
//
//  Protocol for feature flag providers
//

import Foundation
import Combine

/// Protocol for feature flag providers
/// Allows different backends (Firebase Remote Config, custom API, local config, etc.)
public protocol FeatureFlagProvider: AnyObject {
    /// Fetch feature flags from the provider
    /// - Parameter completion: Completion handler with success status and optional error
    func fetchFlags(completion: @escaping (Bool, Error?) -> Void)
    
    /// Get a boolean flag value
    /// - Parameter key: The flag key
    /// - Returns: The flag value, or default if not found
    func boolValue(forKey key: String, defaultValue: Bool) -> Bool
    
    /// Get a string flag value
    /// - Parameter key: The flag key
    /// - Returns: The flag value, or default if not found
    func stringValue(forKey key: String, defaultValue: String) -> String
    
    /// Initialize the provider (call after backend is configured)
    func initialize()
}






