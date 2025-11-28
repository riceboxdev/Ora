//
//  OraBetaApp.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import Kingfisher

@main
struct OraBetaApp: App {
    @StateObject private var container: DIContainer
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var remoteConfigService = RemoteConfigService.shared
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Configure Kingfisher cache for optimal image caching
        Self.configureImageCache()
        
        // Enable logging for image/thumbnail services
        LoggingControl.enable("Post")
        LoggingControl.enable("CachedImageView")
        LoggingControl.enable("PostThumbnailView")
        
        // Create container and AuthViewModel
        let diContainer = DIContainer.shared
        _container = StateObject(wrappedValue: diContainer)
        let authVM = AuthViewModel(container: diContainer)
        _authViewModel = StateObject(wrappedValue: authVM)
    }
    
    /// Configure Kingfisher image cache settings for optimal performance
    /// This reduces network requests by caching images both in memory and on disk
    static func configureImageCache() {
        // Configure memory cache (default: 50MB, 5 minutes)
        // Increase memory cache for better performance
        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100MB
        ImageCache.default.memoryStorage.config.countLimit = 100 // Store up to 100 images in memory
        ImageCache.default.memoryStorage.config.expiration = .seconds(300) // 5 minutes
        
        // Configure disk cache (default: unlimited size, 7 days)
        // Set reasonable limits to prevent excessive disk usage
        ImageCache.default.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500MB disk cache
        ImageCache.default.diskStorage.config.expiration = .days(7) // Keep images for 7 days
        
        // Enable automatic cache cleanup
        ImageCache.default.cleanExpiredCache()
        
        // Log cache configuration (using print since Logger might not be available at init)
        print("✅ Kingfisher cache configured - Memory: 100MB, Disk: 500MB, Expiration: 7 days")
    }
    
    /// Determine the current route based on app state
    private var currentRoute: AppRoute {
        let router = AppRouter(
            authViewModel: authViewModel,
            remoteConfigService: remoteConfigService
        )
        return router.determineRoute()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Route-based view switching
                Group {
                    switch currentRoute {
                    case .splash:
                        SplashScreenView()
                            .transition(AppRoute.splash.transition)
                        
                    case .maintenance:
                        MaintenanceModeView()
                            .transition(AppRoute.maintenance.transition)
                        
                    case .login:
                        LoginView()
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.login.transition)
                        
                    case .onboarding:
                        OnboardingView()
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.onboarding.transition)
                        
                    case .banned:
                        BanScreen()
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.banned.transition)
                        
                    case .main:
                        ContentView()
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.main.transition)
                        
                    case .waitlist:
                        // Waitlist not implemented yet, fall back to login
                        LoginView()
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.waitlist.transition)
                    }
                }
                .animation(currentRoute.animation, value: currentRoute)
            }
        }
    }
}
