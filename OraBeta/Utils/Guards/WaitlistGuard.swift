//
//  WaitlistGuard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
#if canImport(Waitlist)
import Waitlist
#endif

/// Guard that checks if waitlist should be shown for unauthenticated users
struct WaitlistGuard: RouteGuard {
    func check(context: RoutingContext) -> RouteGuardResult {
        #if canImport(Waitlist)
        // Show waitlist if enabled and user is not authenticated
        if context.remoteConfigService.isWaitlistEnabled && !context.authViewModel.isAuthenticated {
            return .redirect(.waitlist)
        }
        #endif
        return .continue
    }
}



