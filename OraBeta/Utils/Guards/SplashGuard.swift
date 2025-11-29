//
//  SplashGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks if authentication is currently being checked or Remote Config is loading
/// Shows splash screen while auth check or config fetch is in progress
struct SplashGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // Show splash while checking auth
        if context.authViewModel.isCheckingAuth {
            Logger.debug("SplashGuard: Showing splash - auth check in progress", service: "SplashGuard")
            return .redirect(.splash)
        }
        
        // Show splash while Remote Config is loading (first fetch)
        // This ensures we have the correct waitlist flag before routing
        if !context.remoteConfigService.isConfigLoaded {
            Logger.debug("SplashGuard: Showing splash - Remote Config not loaded yet", service: "SplashGuard")
            return .redirect(.splash)
        }
        
        Logger.debug("SplashGuard: Auth check complete and Remote Config loaded, continuing routing", service: "SplashGuard")
        return .continue
    }
}






