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
        
        // Enable logging for Remote Config and routing services
        // Register and enable these services explicitly to ensure they're ready
        _ = LoggingServiceRegistry.shared.register(serviceName: "RemoteConfigService")
        _ = LoggingServiceRegistry.shared.register(serviceName: "WaitlistGuard")
        _ = LoggingServiceRegistry.shared.register(serviceName: "SplashGuard")
        LoggingControl.enable("RemoteConfigService")
        LoggingControl.enable("WaitlistGuard")
        LoggingControl.enable("SplashGuard")
        
        // Debug: Print logging state to verify services are enabled
        print("🔧 Logging Configuration:")
        print("   - Default log level: \(LoggingConfig.defaultLogLevel.rawValue)")
        print("   - RemoteConfigService enabled: \(LoggingControl.isEnabled("RemoteConfigService"))")
        print("   - WaitlistGuard enabled: \(LoggingControl.isEnabled("WaitlistGuard"))")
        print("   - SplashGuard enabled: \(LoggingControl.isEnabled("SplashGuard"))")
        
        // Test logging to verify it works - force a test log
        print("🧪 Testing Logger.info()...")
        Logger.info("App initialization complete - logging system ready", service: "OraBetaApp")
        print("🧪 Logger.info() call completed")
        
        // Also test with a service that should definitely work
        Logger.info("Test log from RemoteConfigService", service: "RemoteConfigService")
        Logger.debug("Test debug log from RemoteConfigService", service: "RemoteConfigService")
        
        // Initialize and fetch Remote Config here (after Firebase is configured)
        // This ensures it happens early and we can see the logs
        print("🔧 OraBetaApp: Initializing Remote Config...")
        RemoteConfigService.shared.initialize()
        print("🔧 OraBetaApp: Remote Config initialized, fetching...")
        RemoteConfigService.shared.fetchConfig()
        print("🔧 OraBetaApp: fetchConfig() called")
        
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
    /// This is a computed property that re-evaluates when dependencies change
    @State private var routeRefreshTrigger: Int = 0
    
    private var currentRoute: AppRoute {
        let router = AppRouter(
            authViewModel: authViewModel,
            remoteConfigService: remoteConfigService
        )
        let route = router.determineRoute()
        // Use routeRefreshTrigger to force re-evaluation when needed
        _ = routeRefreshTrigger
        return route
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
                        AppWaitlistView(remoteConfigService: remoteConfigService)
                            .environmentObject(authViewModel)
                            .environmentObject(container)
                            .transition(AppRoute.waitlist.transition)
                    }
                }
                .animation(currentRoute.animation, value: currentRoute)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToLogin"))) { _ in
                // Force route refresh when navigation is requested
                routeRefreshTrigger += 1
            }
        }
    }
}
