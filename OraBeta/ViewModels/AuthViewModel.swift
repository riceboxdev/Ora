//
//  AuthViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isBanned: Bool = false
    
    private let authService: AuthService // Keep concrete type for @Published properties
    private let container: DIContainer
    private let banService = BanService()
    private var cancellables = Set<AnyCancellable>()
    
    init(container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        // Cast to concrete type to access @Published properties
        self.authService = diContainer.authService as! AuthService
        
        print("🔧 AuthViewModel: Initializing")
        
        // Observe authentication state from AuthService
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        // Handle splash screen minimum duration
        Task {
            // 1. Wait for minimum duration (1.5 seconds)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // 2. Wait for actual auth check to complete if it hasn't already
            if authService.isCheckingAuth {
                for await isChecking in authService.$isCheckingAuth.values {
                    if !isChecking { break }
                }
            }
            
            // 3. Dismiss splash screen
            self.isCheckingAuth = false
        }
        
        authService.$currentUser
            .assign(to: &$currentUser)
        
        // When authenticated, fetch profile
        authService.$isAuthenticated
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.fetchUserProfile()
                }
            }
            .store(in: &cancellables)
        
        // When user signs out, clear profile and ban status
        authService.$isAuthenticated
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.userProfile = nil
                self?.isBanned = false
                self?.banService.stopListening()
            }
            .store(in: &cancellables)
    }
    
    /// Fetch the current user's profile from Firestore
    func fetchUserProfile() async {
        guard let userId = authService.userId else {
            print("❌ AuthViewModel: No user ID to fetch profile")
            return
        }
        
        do {
            let profileService = container.profileService
            userProfile = try await profileService.getUserProfile(userId: userId)
            print("✅ AuthViewModel: User profile loaded - onboarding completed: \(userProfile?.isOnboardingCompleted ?? false)")
            
            // Check ban status
            await checkBanStatus()
            
            // Start listening to ban status changes
            banService.startListeningToBanStatus { [weak self] isBanned in
                Task { @MainActor [weak self] in
                    self?.isBanned = isBanned
                }
            }
        } catch {
            print("❌ AuthViewModel: Failed to fetch user profile: \(error.localizedDescription)")
        }
    }
    
    /// Check if current user is banned
    private func checkBanStatus() async {
        do {
            isBanned = try await banService.isBanned()
            print("✅ AuthViewModel: Ban status checked - isBanned: \(isBanned)")
        } catch {
            print("❌ AuthViewModel: Failed to check ban status: \(error.localizedDescription)")
            isBanned = false
        }
    }
    
    // Sign up with email and password
    func signUp(email: String, password: String, displayName: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
            
            // Get user ID after sign up
            guard let userId = authService.userId else {
                print("❌ AuthViewModel: No user ID after sign up")
                errorMessage = "Failed to get user ID after sign up"
                isLoading = false
                return
            }
            
            print("✅ AuthViewModel: User created successfully - \(userId)")
            
            // Create user profile
            print("📝 AuthViewModel: Creating user profile in Firestore...")
            let profileService = container.profileService
            do {
                try await profileService.createProfileFromAuthUser(email: email, displayName: displayName)
                print("✅ AuthViewModel: User profile created successfully")
            } catch {
                print("❌ AuthViewModel: Failed to create user profile: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error domain: \(nsError.domain)")
                    print("   Error code: \(nsError.code)")
                    print("   Error userInfo: \(nsError.userInfo)")
                }
                // Still allow sign up to succeed, but log the error
                errorMessage = "Account created but profile setup failed: \(error.localizedDescription)"
                // Don't throw - allow user to sign in and we can retry profile creation
            }
            
            // Authentication state will be updated automatically via AuthService
        } catch {
            print("❌ AuthViewModel: Sign up failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            
            // Check if profile exists, create it if it doesn't
            if let userId = authService.userId {
                let profileService = container.profileService
                let profileExists = try? await profileService.profileExists()
                
                if profileExists == false {
                    print("⚠️ AuthViewModel: Profile doesn't exist for user \(userId), creating it...")
                    do {
                        try await profileService.createProfileForCurrentUser()
                        print("✅ AuthViewModel: Profile created successfully during sign in")
                    } catch {
                        print("⚠️ AuthViewModel: Failed to create profile during sign in: \(error.localizedDescription)")
                        // Don't fail sign in, but log the error
                    }
                }
            }
            
            // Authentication state will be updated automatically via AuthService
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Sign out
    func signOut() {
        do {
            try authService.signOut()
            // Stop global notification listener
            container.notificationManager.stopListening()
            container.notificationManager.notifications = []
            container.notificationManager.unreadCount = 0
            // Stop ban status listener
            banService.stopListening()
            // Clear user profile and ban status
            userProfile = nil
            isBanned = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

