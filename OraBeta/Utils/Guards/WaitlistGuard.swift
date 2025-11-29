//
//  WaitlistGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
#if canImport(Waitlist)
import Waitlist
#endif

/// Guard that checks if waitlist should be shown for unauthenticated users
/// Also checks if user has been accepted from waitlist and skips waitlist if so
struct WaitlistGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        #if canImport(Waitlist)
        // Only check waitlist if Remote Config has loaded
        // This prevents false negatives from default values
        guard context.remoteConfigService.isConfigLoaded else {
            return .continue
        }
        
        // Show waitlist if enabled and user is not authenticated
        let isEnabled = context.remoteConfigService.isWaitlistEnabled
        let isNotAuthenticated = !context.authViewModel.isAuthenticated
        
        Logger.debug("WaitlistGuard check - isConfigLoaded: \(context.remoteConfigService.isConfigLoaded), isWaitlistEnabled: \(isEnabled), isAuthenticated: \(context.authViewModel.isAuthenticated)", service: "WaitlistGuard")
        
        // If waitlist is enabled and user is not authenticated, check if they've been accepted
        if isEnabled && isNotAuthenticated {
            // Check if user has been accepted from waitlist (stored in UserDefaults)
            if let config = getWaitlistConfig() {
                let client = WaitlistClient(config: config)
                
                // Check if user has joined
                if client.hasJoined() {
                    // Check if we have stored acceptance status
                    let acceptanceKey = "WaitlistAccepted_\(config.waitlistId)"
                    let isAccepted = UserDefaults.standard.bool(forKey: acceptanceKey)
                    
                    if isAccepted {
                        // User has been accepted - skip waitlist and continue to login
                        Logger.info("User has been accepted from waitlist, skipping waitlist", service: "WaitlistGuard")
                        return .continue
                    } else {
                        // User has joined but not yet accepted - show waitlist
                        Logger.info("User has joined waitlist but not yet accepted, showing waitlist", service: "WaitlistGuard")
                        return .redirect(.waitlist)
                    }
                } else {
                    // User hasn't joined yet, show waitlist
                    Logger.info("User hasn't joined waitlist yet, showing waitlist", service: "WaitlistGuard")
                    return .redirect(.waitlist)
                }
            } else {
                // No waitlist config, show waitlist anyway (will show error)
                Logger.info("Redirecting to waitlist (no config)", service: "WaitlistGuard")
                return .redirect(.waitlist)
            }
        }
        #endif
        return .continue
    }
    
    #if canImport(Waitlist)
    private func getWaitlistConfig() -> WaitlistConfig? {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "WAITLIST_API_KEY") as? String
        let waitlistId = Bundle.main.object(forInfoDictionaryKey: "WAITLIST_ID") as? String
        let baseURL = (Bundle.main.object(forInfoDictionaryKey: "WAITLIST_BASE_URL") as? String) ?? WaitlistConfig.defaultBaseURL
        
        guard let apiKey, let waitlistId, !apiKey.isEmpty, !waitlistId.isEmpty else {
            return nil
        }
        
        let config = WaitlistConfig(apiKey: apiKey, waitlistId: waitlistId, baseURL: baseURL)
        return config.isValid ? config : nil
    }
    #endif
}






