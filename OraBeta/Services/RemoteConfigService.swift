//
//  RemoteConfigService.swift
//  OraBeta
//
//  Re-export from FeatureFlags package with Firebase implementation
//

import Foundation
import FirebaseRemoteConfig
import Combine
@_exported import FeatureFlags

/// Service to handle Firebase Remote Config
/// Re-exported from FeatureFlags package for backward compatibility
@available(iOS 15.0, *)
public class RemoteConfigService: ObservableObject {
    public static let shared = RemoteConfigService()
    
    private let featureFlagService: FeatureFlagService
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var areAdsEnabled: Bool = true
    @Published public var isWaitlistEnabled: Bool = false
    @Published public var isStoriesEnabled: Bool = false
    @Published public var isMaintenanceMode: Bool = false
    @Published public var adFrequency: Int = 5 // Show ad every N posts (default: 5)
    
    private init() {
        // Create Firebase provider with default configuration
        let defaults: [String: NSObject] = [
            "showAds": true as NSObject,
            "waitlistEnabled": false as NSObject,
            "maintenanceMode": false as NSObject,
            "adFrequency": "5" as NSObject, // String because Remote Config stores all values as strings
            "featureFlags": "" as NSObject
        ]
        
        let provider = FirebaseFeatureFlagProvider(defaults: defaults)
        self.featureFlagService = FeatureFlagService(provider: provider)
        
        // Observe changes from the service
        featureFlagService.$areAdsEnabled
            .sink { [weak self] value in
                self?.areAdsEnabled = value
            }
            .store(in: &cancellables)
        
        featureFlagService.$isWaitlistEnabled
            .sink { [weak self] value in
                self?.isWaitlistEnabled = value
            }
            .store(in: &cancellables)
        
        featureFlagService.$isStoriesEnabled
            .sink { [weak self] value in
                self?.isStoriesEnabled = value
            }
            .store(in: &cancellables)
        
        featureFlagService.$isMaintenanceMode
            .sink { [weak self] value in
                self?.isMaintenanceMode = value
            }
            .store(in: &cancellables)
        
        featureFlagService.$adFrequency
            .sink { [weak self] value in
                self?.adFrequency = value
            }
            .store(in: &cancellables)
    }
    
    /// Initialize Remote Config (call this after Firebase is configured)
    public func initialize() {
        featureFlagService.initialize()
    }
    
    /// Fetch config from remote
    public func fetchConfig() {
        featureFlagService.fetchConfig()
    }
}

/// Global helper for accessing feature flags in a centralized, type-safe way
/// - Note: For SwiftUI views that need to react to flag changes live,
///   prefer observing `RemoteConfigService` as an `ObservableObject`.
@available(iOS 15.0, *)
public struct FeatureFlags {
    /// Whether ads should be displayed, combining local and remote state.
    /// This currently reflects only the Remote Config value; UI may apply
    /// additional local toggles (e.g., `@AppStorage("areAdsEnabled")`).
    public static var areAdsEnabled: Bool {
        RemoteConfigService.shared.areAdsEnabled
    }
    
    /// Whether the waitlist experience should be shown for unauthenticated users.
    public static var isWaitlistEnabled: Bool {
        RemoteConfigService.shared.isWaitlistEnabled
    }
    
    /// Whether the Stories feature is enabled in the app.
    /// This is controlled primarily via the `featureFlags` Remote Config JSON.
    public static var isStoriesEnabled: Bool {
        RemoteConfigService.shared.isStoriesEnabled
    }
    
    /// Whether maintenance mode is active.
    /// When true, the app should show a maintenance screen.
    public static var isMaintenanceMode: Bool {
        RemoteConfigService.shared.isMaintenanceMode
    }
}
