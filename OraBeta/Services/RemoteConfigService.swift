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
    @Published public var isConfigLoaded: Bool = false // Track if initial config fetch has completed
    
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
        // Mark as not loaded initially - will be set to true when fetch completes
        isConfigLoaded = false
    }
    
    /// Fetch config from remote
    public func fetchConfig() {
        print("🔧 RemoteConfigService.fetchConfig() called - isConfigLoaded: \(isConfigLoaded)")
        
        // Prevent multiple simultaneous fetches
        guard !isConfigLoaded else {
            Logger.debug("Remote Config already loaded, skipping fetch", service: "RemoteConfigService")
            print("🔧 RemoteConfigService: Already loaded, skipping fetch")
            return
        }
        
        print("🔧 RemoteConfigService: About to log 'Fetching Remote Config...'")
        Logger.info("Fetching Remote Config...", service: "RemoteConfigService")
        print("🔧 RemoteConfigService: Logged fetch message, about to call featureFlagService.fetchConfig()")
        
        // Add a timeout fallback to ensure we don't stay on splash forever
        var timeoutTask: DispatchWorkItem?
        timeoutTask = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isConfigLoaded else { return }
            Logger.warning("Remote Config fetch timed out after 5 seconds, using defaults", service: "RemoteConfigService")
            self.isConfigLoaded = true
        }
        
        // Schedule timeout for 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: timeoutTask!)
        
        print("🔧 RemoteConfigService: Calling featureFlagService.fetchConfig()...")
        featureFlagService.fetchConfig { [weak self] success in
            print("🔧 RemoteConfigService: fetchConfig completion called - success: \(success)")
            timeoutTask?.cancel() // Cancel timeout if fetch completes
            DispatchQueue.main.async {
                guard let self = self else {
                    print("🔧 RemoteConfigService: Self is nil in completion handler")
                    return
                }
                
                print("🔧 RemoteConfigService: Setting isConfigLoaded = true")
                // Always mark as loaded after fetch attempt (success or failure)
                self.isConfigLoaded = true
                
                if success {
                    Logger.info("Remote Config fetched and activated successfully", service: "RemoteConfigService")
                    Logger.debug("Remote Config values - isWaitlistEnabled: \(self.isWaitlistEnabled), areAdsEnabled: \(self.areAdsEnabled), isMaintenanceMode: \(self.isMaintenanceMode), isStoriesEnabled: \(self.isStoriesEnabled)", service: "RemoteConfigService")
                    print("🔧 RemoteConfigService: ✅ Fetch successful - isWaitlistEnabled: \(self.isWaitlistEnabled)")
                } else {
                    Logger.warning("Remote Config fetch failed, using defaults - isWaitlistEnabled (default): \(self.isWaitlistEnabled)", service: "RemoteConfigService")
                    print("🔧 RemoteConfigService: ⚠️ Fetch failed - using defaults - isWaitlistEnabled: \(self.isWaitlistEnabled)")
                }
            }
        }
        print("🔧 RemoteConfigService: fetchConfig() method completed (async fetch in progress)")
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
