//
//  ContentView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

enum AppTab: Hashable {
    case home
    case discover
    case search
    case activity
    case profile
}

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var container: DIContainer
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var taggingViewModel = PostTaggingViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var isAdmin = false
    @State private var showCreatePost = false
    @State private var showBulkUpload = false
    @State private var showTaggingView = false
    @State private var hasCheckedUntaggedPosts = false
    
    var body: some View {
        ZStack {
            // Main tab view - disabled if tagging is required
            TabView(selection: $selectedTab) {
                Tab("Home", image: "home.regular", value: AppTab.home) {
                    HomeFeedView()
                }
                
                Tab("Discover", image: "globe.regular", value: AppTab.discover) {
                    DiscoverFeedView()
                }
                
                Tab("Search", image: "search.regular", value: AppTab.search, role: .search) {
                    SearchView()
                }
                
                if notificationManager.unreadCount > 0 {
                    Tab("Activity", image: "bell.regular", value: AppTab.activity) {
                        NotificationsView()
                    }
                    .badge(notificationManager.unreadCount)
                } else {
                    Tab("Activity", image: "bell.regular", value: AppTab.activity) {
                        NotificationsView()
                    }
                }
                
                Tab("Profile", image: "person.regular", value: AppTab.profile) {
                    ProfileView()
                }
            }
            .disabled(showTaggingView) // Block tab navigation when tagging is required
            .tabBarMinimizeBehavior(.onScrollDown)
            .toastNotifications(notificationManager: notificationManager, selectedTab: Binding(
                get: {
                    switch selectedTab {
                    case .home: return 0
                    case .discover: return 1
                    case .search: return 2
                    case .activity: return 3
                    case .profile: return 4
                    }
                },
                set: { value in
                    switch value {
                    case 0: selectedTab = .home
                    case 1: selectedTab = .discover
                    case 2: selectedTab = .search
                    case 3: selectedTab = .activity
                    case 4: selectedTab = .profile
                    default: selectedTab = .home
                    }
                }
            ))
            .task {
                await checkAdminStatus()
                await setupGlobalNotifications()
                // Temporarily disabled: await checkUntaggedPosts()
            }
        }
        .fullScreenCover(isPresented: $showTaggingView) {
            PostTaggingView(onComplete: {
                // Re-check after tagging is complete
                hasCheckedUntaggedPosts = false
                Task {
                    // Temporarily disabled: await checkUntaggedPosts()
                }
            })
            .zIndex(1000)
            .onDisappear {
                // Re-check after tagging is complete
                hasCheckedUntaggedPosts = false
                Task {
                    // Temporarily disabled: await checkUntaggedPosts()
                }
            }
        }
    }
    
    private func checkUntaggedPosts() async {
        // Temporarily disabled - returning early
        return
        
        // Only check once per session
        guard !hasCheckedUntaggedPosts else { return }
        hasCheckedUntaggedPosts = true
        
        // Small delay to let app finish loading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let hasUntagged = await taggingViewModel.hasUntaggedPosts()
        if hasUntagged {
            // Show blocking UI
            await MainActor.run {
                showTaggingView = true
            }
        }
    }
    
    private func setupGlobalNotifications() async {
        guard let userId = authViewModel.currentUser?.uid else {
            return
        }
        
        print("🔔 ContentView: Setting up global notifications")
        
        // Start Firestore listener for notifications
        notificationManager.startListening(userId: userId)
        
        // Initial load
        await notificationManager.loadNotifications()
    }
    
    private func checkAdminStatus() async {
        guard let userId = authViewModel.currentUser?.uid else {
            return
        }
        
        do {
            // Check if profile exists first
            let profileService = container.profileService
            let profileExists = try await profileService.profileExists()
            
            if !profileExists {
                print("⚠️ ContentView: Profile doesn't exist for user \(userId), creating it...")
                do {
                    try await profileService.createProfileForCurrentUser()
                    print("✅ ContentView: Profile created successfully")
                } catch {
                    print("⚠️ ContentView: Failed to create profile: \(error.localizedDescription)")
                }
            }
            
            // Now check admin status (will return false if profile doesn't exist, which is correct)
            isAdmin = try await profileService.isAdmin(userId: userId)
            print("✅ ContentView: Admin status checked - isAdmin: \(isAdmin)")
        } catch {
            print("❌ ContentView: Error checking admin status: \(error)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
            }
            // Default to non-admin if there's an error
            isAdmin = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
