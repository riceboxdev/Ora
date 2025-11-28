//
//  SplashGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks if authentication is currently being checked
/// Shows splash screen while auth check is in progress
struct SplashGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        if context.authViewModel.isCheckingAuth {
            return .redirect(.splash)
        }
        return .continue
    }
}



