//
//  OnboardingGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks if an authenticated user has completed onboarding
struct OnboardingGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // Only check onboarding for authenticated users
        guard context.authViewModel.isAuthenticated else {
            return .continue
        }
        
        // If profile is not loaded yet, we can't determine onboarding status
        // In this case, we'll let the profile load and check again on next route determination
        guard let profile = context.authViewModel.userProfile else {
            // If authenticated but profile is nil, show onboarding as safe default for new users
            return .redirect(.onboarding)
        }
        
        // Show onboarding if not completed
        if !profile.isOnboardingCompleted {
            return .redirect(.onboarding)
        }
        
        return .continue
    }
}



