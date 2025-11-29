//
//  MaintenanceModeGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation

/// Guard that checks if the app is in maintenance mode
/// This guard blocks all other routing and shows the maintenance screen
struct MaintenanceModeGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        if context.remoteConfigService.isMaintenanceMode {
            return .block(.maintenance)
        }
        return .continue
    }
}






