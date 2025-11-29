//
//  RouteGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Context passed to route guards containing all necessary services and view models
struct RoutingContext {
    let authViewModel: AuthViewModel
    let remoteConfigService: RemoteConfigService
}

/// Result of a route guard check
enum RouteGuardResult {
    /// Continue to the next guard in the pipeline
    case `continue`
    
    /// Redirect to a specific route (allows navigation)
    case redirect(AppRoute)
    
    /// Block and show a specific route (prevents navigation, like maintenance mode)
    case block(AppRoute)
}

/// Protocol for route guards that check app state and determine routing
protocol RouteGuard {
    /// Checks the current app state and returns a routing decision
    /// - Parameter context: The routing context containing services and view models
    /// - Returns: A route guard result indicating whether to continue, redirect, or block
    func check(context: RoutingContext) -> RouteGuardResult
}






