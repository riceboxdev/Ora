//
//  RouteGuardPipeline.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Executes route guards in sequence, stopping at the first non-continue result
struct RouteGuardPipeline {
    private let guards: [RouteGuard]
    
    /// Initialize pipeline with an ordered array of guards
    /// - Parameter guards: Array of guards to execute in order
    init(guards: [RouteGuard]) {
        self.guards = guards
    }
    
    /// Execute all guards in sequence, returning the first route decision
    /// - Parameter context: The routing context to pass to each guard
    /// - Returns: The route determined by the first guard that doesn't continue, or `.login` as fallback
    func execute(context: RoutingContext) -> AppRoute {
        for routeGuard in guards {
            let result = routeGuard.check(context: context)
            
            switch result {
            case .continue:
                // Continue to next guard
                continue
                
            case .redirect(let route), .block(let route):
                // Stop and return the route
                return route
            }
        }
        
        // Fallback to login if all guards continue (shouldn't happen in practice)
        return .login
    }
}

