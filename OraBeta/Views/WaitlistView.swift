//
//  WaitlistView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/29/25.
//

import SwiftUI
#if canImport(Waitlist)
import Waitlist
#endif

/// Waitlist view that integrates the Velvet SDK
/// This view is shown when waitlist is enabled and user is not authenticated
struct AppWaitlistView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let remoteConfigService: RemoteConfigService
    
    var body: some View {
        // Use custom waitlist view styled to match onboarding
        CustomWaitlistView(remoteConfigService: remoteConfigService)
    }
}

#if canImport(Waitlist)
/// Wrapper around the Velvet SDK's WaitlistView
/// Uses a different name to avoid conflict with the SDK's WaitlistView
private struct VelvetWaitlistView: View {
    let config: WaitlistConfig
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        // Use the SDK's WaitlistView directly from the Waitlist module
        // Fully qualified to avoid any naming conflicts
        Waitlist.WaitlistView(
            config: config,
            title: "Join the Waitlist",
            subtitle: "Be among the first to experience Ora. We'll notify you when it's your turn.",
            buttonText: "Join Waitlist",
            successMessage: "You're on the list! We'll notify you when we launch.",
            onAccepted: {
                // When user is accepted, the routing pipeline will automatically
                // re-evaluate and route them appropriately
                // No action needed here as the router checks on each route determination
            }
        )
    }
}
#endif

/// Error view shown when waitlist configuration is missing or SDK is unavailable
private struct WaitlistErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Waitlist Unavailable")
                .font(.title)
                .fontWeight(.bold)
            
            Text("The waitlist feature is not properly configured. Please contact support.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

