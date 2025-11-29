//
//  AuthenticationGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks authentication status
/// This guard doesn't redirect but allows downstream guards to know auth state
/// It always continues to let subsequent guards handle authenticated vs unauthenticated routing
struct AuthenticationGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // This guard doesn't redirect - it just allows the pipeline to continue
        // Downstream guards (BanGuard, OnboardingGuard, MainRouteGuard, LoginGuard)
        // will check authentication status and route accordingly
        return .continue
    }
}






