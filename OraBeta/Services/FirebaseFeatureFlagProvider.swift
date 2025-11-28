//
//  FirebaseFeatureFlagProvider.swift
//  OraBeta
//
//  Firebase Remote Config implementation of FeatureFlagProvider
//  This is in the app (not the package) to avoid Firebase dependency in the package
//

import Foundation
import FirebaseRemoteConfig
import FeatureFlags

/// Firebase Remote Config implementation of FeatureFlagProvider
@available(iOS 15.0, *)
public class FirebaseFeatureFlagProvider: FeatureFlagProvider {
    private var remoteConfig: RemoteConfig?
    
    /// Configuration for fetch intervals
    public struct FetchConfig {
        public let debugFetchInterval: TimeInterval
        public let productionFetchInterval: TimeInterval
        
        public init(
            debugFetchInterval: TimeInterval = 0,
            productionFetchInterval: TimeInterval = 43200 // 12 hours
        ) {
            self.debugFetchInterval = debugFetchInterval
            self.productionFetchInterval = productionFetchInterval
        }
    }
    
    private let fetchConfig: FetchConfig
    private let defaults: [String: NSObject]
    
    /// Initialize with fetch configuration and default values
    /// - Parameters:
    ///   - fetchConfig: Configuration for fetch intervals
    ///   - defaults: Default values for flags
    public init(
        fetchConfig: FetchConfig = FetchConfig(),
        defaults: [String: NSObject] = [:]
    ) {
        self.fetchConfig = fetchConfig
        self.defaults = defaults
    }
    
    public func initialize() {
        guard remoteConfig == nil else { return }
        self.remoteConfig = RemoteConfig.remoteConfig()
        setupRemoteConfig()
    }
    
    private func setupRemoteConfig() {
        guard let remoteConfig = remoteConfig else { return }
        let settings = RemoteConfigSettings()
        
        #if DEBUG
        settings.minimumFetchInterval = fetchConfig.debugFetchInterval
        #else
        settings.minimumFetchInterval = fetchConfig.productionFetchInterval
        #endif
        
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaults)
    }
    
    public func fetchFlags(completion: @escaping (Bool, Error?) -> Void) {
        guard let remoteConfig = remoteConfig else {
            completion(false, NSError(domain: "FeatureFlags", code: -1, userInfo: [NSLocalizedDescriptionKey: "RemoteConfig not initialized"]))
            return
        }
        
        remoteConfig.fetch { [weak self] status, error in
            guard let self = self, let remoteConfig = self.remoteConfig else {
                completion(false, error)
                return
            }
            
            if status == .success {
                remoteConfig.activate { changed, error in
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            } else {
                completion(false, error)
            }
        }
    }
    
    public func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        guard let remoteConfig = remoteConfig else { return defaultValue }
        return remoteConfig.configValue(forKey: key).boolValue
    }
    
    public func stringValue(forKey key: String, defaultValue: String) -> String {
        guard let remoteConfig = remoteConfig else { return defaultValue }
        let value = remoteConfig.configValue(forKey: key).stringValue ?? ""
        return value.isEmpty ? defaultValue : value
    }
}



