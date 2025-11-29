//
//  MainRouteGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that routes authenticated users who have passed all checks to the main app
struct MainRouteGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // Only route to main for authenticated users
        if context.authViewModel.isAuthenticated {
            return .redirect(.main)
        }
        return .continue
    }
}






