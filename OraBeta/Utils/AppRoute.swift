//
//  AppRoute.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import SwiftUI

/// Reusable transition styles for easy customization
extension AnyTransition {
    /// Android Material Design style transition: fades in while sliding up
    /// - Parameter offset: Vertical offset for the slide (default: 20 points)
    static func androidStyle(offset: CGFloat = 20) -> AnyTransition {
        return .asymmetric(
            insertion: .modifier(
                active: AndroidTransitionModifier(offset: offset, opacity: 0),
                identity: AndroidTransitionModifier(offset: 0, opacity: 1)
            ).animation(.smooth),
            removal: .modifier(
                active: AndroidTransitionModifier(offset: -offset, opacity: 0),
                identity: AndroidTransitionModifier(offset: 0, opacity: 1)
            ).animation(.smooth)
        )
    }
}

/// Helper modifier for Android-style transitions
private struct AndroidTransitionModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
    }
}

/// Represents all possible entry point screens in the app.
/// Used by AppRouter to determine which screen should be displayed.
enum AppRoute: Hashable, Equatable {
    /// Initial loading screen shown while checking authentication state
    case splash
    
    /// Waitlist screen for logged-out users (when waitlist feature is enabled)
    case waitlist
    
    /// Login screen for logged-out users
    case login
    
    /// Onboarding flow for authenticated users who haven't completed onboarding
    case onboarding
    
    /// Ban screen for banned users
    case banned
    
    /// Main tab view (ContentView) for authenticated users who have completed onboarding
    case main
    
    /// Maintenance mode screen shown when app is in maintenance mode
    case maintenance
    
    // MARK: - Transitions
    
    /// Returns the transition animation for this route.
    /// Customize transitions here to easily change animations throughout the app.
    /// 
    /// Available transition styles:
    /// - `.opacity` - Simple fade
    /// - `.move(edge:)` - Slide from edge
    /// - `.androidStyle()` - Android Material Design style (fade + slide up)
    /// - `.scale` - Scale animation
    /// - Combine with `.combined(with:)` for multiple effects
    var transition: AnyTransition {
        switch self {
        case .splash:
            // Fade in for splash screen
            return .opacity
            
        case .waitlist:
            // Android-style fade and slide up for waitlist
            return .androidStyle(offset: 30)
            
        case .login:
            // Android-style fade and slide up for login
            return .androidStyle(offset: 25)
            
        case .onboarding:
            // Android-style fade and slide up for onboarding
            return .androidStyle(offset: 20)
            
        case .banned:
            // Fade in for ban screen (serious, direct)
            return .opacity
            
        case .main:
            // Android-style fade and slide up for main app
            return .androidStyle(offset: 30)
            
        case .maintenance:
            // Fade in for maintenance screen
            return .opacity
        }
    }
    
    /// Returns the animation curve and duration for this route's transition.
    /// Customize timing here to easily adjust animation feel.
    /// 
    /// Android-style transitions typically use a decelerate curve for a natural feel.
    var animation: Animation {
        switch self {
        case .splash:
            // Quick fade for splash
            return .easeInOut(duration: 0.3)
            
        case .waitlist:
            // Android-style: smooth decelerate curve
            return .easeOut(duration: 0.35)
            
        case .login:
            // Android-style: smooth decelerate curve
            return .easeOut(duration: 0.35)
            
        case .onboarding:
            // Android-style: slightly slower for welcoming feel
            return .easeOut(duration: 0.4)
            
        case .banned:
            // Quick fade for ban screen
            return .easeInOut(duration: 0.4)
            
        case .main:
            // Android-style: smooth decelerate curve
            return .easeOut(duration: 0.35)
            
        case .maintenance:
            // Quick fade for maintenance screen
            return .easeInOut(duration: 0.3)
        }
    }
}

