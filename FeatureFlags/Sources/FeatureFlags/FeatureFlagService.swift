//
//  FeatureFlagService.swift
//  FeatureFlags
//
//  Observable service for managing feature flags
//

import Foundation
import Combine

/// Observable service for managing feature flags
/// Works with any FeatureFlagProvider implementation
@available(iOS 15.0, macOS 12.0, *)
public class FeatureFlagService: ObservableObject {
    private let provider: FeatureFlagProvider
    
    /// Whether ads are enabled
    @Published public var areAdsEnabled: Bool = true
    
    /// Whether waitlist is enabled
    @Published public var isWaitlistEnabled: Bool = false
    
    /// Whether stories feature is enabled
    @Published public var isStoriesEnabled: Bool = false
    
    /// Whether maintenance mode is active
    @Published public var isMaintenanceMode: Bool = false
    
    /// Configuration for feature flag keys
    public struct Config {
        public let adsEnabledKey: String
        public let waitlistEnabledKey: String
        public let storiesEnabledKey: String
        public let maintenanceModeKey: String
        public let featureFlagsJSONKey: String
        
        public init(
            adsEnabledKey: String = "showAds",
            waitlistEnabledKey: String = "waitlistEnabled",
            storiesEnabledKey: String = "storiesEnabled",
            maintenanceModeKey: String = "maintenanceMode",
            featureFlagsJSONKey: String = "featureFlags"
        ) {
            self.adsEnabledKey = adsEnabledKey
            self.waitlistEnabledKey = waitlistEnabledKey
            self.storiesEnabledKey = storiesEnabledKey
            self.maintenanceModeKey = maintenanceModeKey
            self.featureFlagsJSONKey = featureFlagsJSONKey
        }
    }
    
    private let config: Config
    
    /// Initialize with a provider and configuration
    /// - Parameters:
    ///   - provider: The feature flag provider to use
    ///   - config: Configuration for flag keys (optional, uses defaults)
    public init(provider: FeatureFlagProvider, config: Config = Config()) {
        self.provider = provider
        self.config = config
    }
    
    /// Initialize the service (call after backend is configured)
    public func initialize() {
        provider.initialize()
        fetchConfig()
    }
    
    /// Fetch feature flags from the provider
    public func fetchConfig() {
        provider.fetchFlags { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.async {
                    self.updateValues()
                }
            } else if let error = error {
                print("FeatureFlags: Failed to fetch flags: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update published values from the provider
    private func updateValues() {
        // Start with simple scalar values
        var adsEnabled = provider.boolValue(forKey: config.adsEnabledKey, defaultValue: true)
        var waitlistEnabled = provider.boolValue(forKey: config.waitlistEnabledKey, defaultValue: false)
        let maintenanceMode = provider.boolValue(forKey: config.maintenanceModeKey, defaultValue: false)
        var storiesEnabled = false
        
        // Try to read JSON-based feature flags
        let jsonValue = provider.stringValue(forKey: config.featureFlagsJSONKey, defaultValue: "")
        if !jsonValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let data = jsonValue.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode(RemoteFeatureFlags.self, from: data)
                
                if let jsonAdsEnabled = decoded.adsEnabled {
                    adsEnabled = jsonAdsEnabled
                }
                if let jsonWaitlistEnabled = decoded.waitlistEnabled {
                    waitlistEnabled = jsonWaitlistEnabled
                }
                if let jsonStoriesEnabled = decoded.storiesEnabled {
                    storiesEnabled = jsonStoriesEnabled
                }
            } catch {
                print("FeatureFlags: Failed to decode featureFlags JSON: \(error.localizedDescription)")
            }
        }
        
        // Publish final values
        self.areAdsEnabled = adsEnabled
        self.isWaitlistEnabled = waitlistEnabled
        self.isStoriesEnabled = storiesEnabled
        self.isMaintenanceMode = maintenanceMode
    }
    
    /// Decodable model for JSON-based feature flags
    private struct RemoteFeatureFlags: Decodable {
        let storiesEnabled: Bool?
        let adsEnabled: Bool?
        let waitlistEnabled: Bool?
    }
}

