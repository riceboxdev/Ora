//
//  BanGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks if an authenticated user is banned
struct BanGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // Only check ban status for authenticated users
        if context.authViewModel.isAuthenticated && context.authViewModel.isBanned {
            return .redirect(.banned)
        }
        return .continue
    }
}






