//
//  AppRouter.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
#if canImport(Waitlist)
import Waitlist
#endif

/// Determines the appropriate entry point route based on app state.
/// Centralizes all routing logic for easy maintenance and testing.
struct AppRouter {
    let authViewModel: AuthViewModel
    let remoteConfigService: RemoteConfigService
    
    /// Determines the current route based on authentication state, user profile, and feature flags.
    /// Uses a pipeline of route guards to check conditions in order:
    /// 1. Maintenance mode (blocks all other routing)
    /// 2. Splash screen (if checking auth)
    /// 3. Waitlist (if enabled and not authenticated)
    /// 4. Authentication check (passes through)
    /// 5. Ban status (if authenticated and banned)
    /// 6. Onboarding (if authenticated but onboarding not completed)
    /// 7. Main (if authenticated and onboarding completed)
    /// 8. Login (fallback for unauthenticated users)
    func determineRoute() -> AppRoute {
        let context = RoutingContext(
            authViewModel: authViewModel,
            remoteConfigService: remoteConfigService
        )
        
        // Create pipeline with guards in priority order
        let pipeline = RouteGuardPipeline(guards: [
            MaintenanceModeGuard(),    // Check maintenance mode first (blocks everything)
            SplashGuard(),             // Show splash while checking auth
            WaitlistGuard(),           // Show waitlist if enabled
            AuthenticationGuard(),     // Pass through for auth state awareness
            BanGuard(),                // Check ban status for authenticated users
            OnboardingGuard(),         // Check onboarding completion
            MainRouteGuard(),          // Route authenticated users to main
            LoginGuard()               // Fallback to login for unauthenticated users
        ])
        
        return pipeline.execute(context: context)
    }
    
    /// Determines if onboarding should be shown
    var shouldShowOnboarding: Bool {
        guard authViewModel.isAuthenticated else { return false }
        guard let profile = authViewModel.userProfile else {
            // If authenticated but profile is nil, we need to wait for it to load
            // Return true to show onboarding as a safe default for new users
            return authViewModel.isAuthenticated
        }
        return !profile.isOnboardingCompleted
    }
    
    // MARK: - Waitlist Logic
    
    #if canImport(Waitlist)
    /// Determines if waitlist should be shown
    private var shouldShowWaitlist: Bool {
        remoteConfigService.isWaitlistEnabled && !authViewModel.isAuthenticated
    }
    
    /// Gets the waitlist configuration if available
    var waitlistConfig: WaitlistConfig? {
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

