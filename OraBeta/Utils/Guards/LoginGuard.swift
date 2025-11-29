//
//  LoginGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Fallback guard that routes unauthenticated users to login
/// This should be the last guard in the pipeline
struct LoginGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        // This is the fallback for unauthenticated users
        // If we reach here, user is not authenticated and should see login
        return .redirect(.login)
    }
}






