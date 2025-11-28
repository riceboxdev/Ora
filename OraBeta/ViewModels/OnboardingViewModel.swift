//
//  OnboardingViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var username: String = "" {
        didSet {
            // Update cached validation properties when username changes
            updateValidationCache()
        }
    }
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var selectedImage: UIImage?
    
    @Published var isUsernameAvailable: Bool = false
    @Published var isCheckingUsername: Bool = false
    @Published var usernameError: String?
    
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var showError: Bool = false
    
    @Published var currentPageIndex: Int = 0
    
    // MARK: - Email Verification Properties
    @Published var isEmailVerified: Bool = false
    @Published var isEmailVerificationSent: Bool = false
    @Published var isSendingVerificationEmail: Bool = false
    @Published var lastEmailSentTime: Date?
    
    // MARK: - Cached Validation Properties (to avoid recalculating in views)
    @Published var meetsMinLength: Bool = false
    @Published var hasNoSpaces: Bool = false
    
    // MARK: - Dependencies
    private let profileService: ProfileServiceProtocol
    private let imageUploadService: ImageUploadService
    private let authService: AuthServiceProtocol
    private var authViewModel: AuthViewModel?
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUsernameCheckTask: Task<Void, Never>?
    
    // MARK: - Init
    init(container: DIContainer = DIContainer.shared, authViewModel: AuthViewModel? = nil) {
        self.profileService = container.profileService
        self.imageUploadService = container.imageUploadService
        self.authService = container.authService
        self.authViewModel = authViewModel
        
        setupUsernameValidation()
    }
    
    // MARK: - Public Methods
    
    /// Set the AuthViewModel after initialization (for environment object injection)
    func setAuthViewModel(_ authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        // Check email verification status when authViewModel is set
        Task {
            await checkEmailVerificationStatus()
        }
    }
    
    // MARK: - Username Validation
    
    /// Update cached validation properties to avoid recalculating in views
    private func updateValidationCache() {
        meetsMinLength = username.count >= 3
        hasNoSpaces = username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }
    
    private func setupUsernameValidation() {
        $username
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] username in
                guard let self = self else { return }
                
                // Cancel any existing username check task
                self.currentUsernameCheckTask?.cancel()
                
                if !username.isEmpty {
                    // Create new task and store it for potential cancellation
                    self.currentUsernameCheckTask = Task { @MainActor in
                        await self.checkUsername(username)
                    }
                } else {
                    self.isUsernameAvailable = false
                    self.usernameError = nil
                    self.isCheckingUsername = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkUsername(_ username: String) async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        // Basic validation
        guard username.count >= 3 else {
            self.usernameError = "Username must be at least 3 characters"
            self.isUsernameAvailable = false
            self.isCheckingUsername = false
            return
        }
        
        guard username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            self.usernameError = "Username cannot contain spaces"
            self.isUsernameAvailable = false
            self.isCheckingUsername = false
            return
        }
        
        // Check if task was cancelled before making network call
        guard !Task.isCancelled else { return }
        
        self.isCheckingUsername = true
        self.usernameError = nil
        
        do {
            // Check availability via service
            let isAvailable = try await profileService.checkUsernameAvailability(username: username)
            
            // Check again if task was cancelled after network call
            guard !Task.isCancelled else { return }
            
            self.isUsernameAvailable = isAvailable
            if !isAvailable {
                self.usernameError = "Username is already taken"
            }
        } catch {
            // Only update if not cancelled
            guard !Task.isCancelled else { return }
            self.usernameError = "Error checking availability"
            print("Error checking username: \(error)")
        }
        
        self.isCheckingUsername = false
    }
    
    // MARK: - Email Verification
    
    /// Check current email verification status synchronously (without reloading user)
    /// Use this for initial state checks to avoid showing wrong screen
    func checkEmailVerificationStatusSync() {
        isEmailVerified = authService.isEmailVerified
    }
    
    /// Check if the user's email is verified (reloads user to get latest status)
    func checkEmailVerificationStatus() async {
        // Reload the user to get latest verification status
        do {
            try await authService.reloadUser()
            isEmailVerified = authService.isEmailVerified
        } catch {
            // If reload fails, just check current status
            isEmailVerified = authService.isEmailVerified
        }
    }
    
    /// Send email verification
    func sendVerificationEmail() async {
        isSendingVerificationEmail = true
        error = nil
        
        do {
            try await authService.sendEmailVerification()
            isEmailVerificationSent = true
            lastEmailSentTime = Date()
            // Check status after sending
            await checkEmailVerificationStatus()
        } catch {
            self.error = error
            self.showError = true
        }
        
        isSendingVerificationEmail = false
    }
    
    /// Check if resend button should be shown (within 60 seconds of last send)
    var shouldShowResendButton: Bool {
        guard let lastSent = lastEmailSentTime else { return false }
        return Date().timeIntervalSince(lastSent) < 60
    }
    
    /// Get remaining seconds until resend button should be hidden
    var resendCooldownSeconds: Int {
        guard let lastSent = lastEmailSentTime else { return 0 }
        let elapsed = Date().timeIntervalSince(lastSent)
        let remaining = max(0, 60 - Int(elapsed))
        return remaining
    }
    
    // MARK: - Actions
    
    func completeOnboarding() async {
        guard let userId = authService.userId else {
            self.error = ProfileError.noUserId
            self.showError = true
            return
        }
        
        self.isLoading = true
        
        do {
            var profilePhotoUrl: String?
            
            // Upload image if selected
            if let image = selectedImage {
                // Upload image using legacy method which handles processing
                let result = try await imageUploadService.uploadImage(image, userId: userId)
                profilePhotoUrl = result.imageUrl
            }
            
            // Update profile
            try await profileService.completeOnboarding(
                userId: userId,
                username: username,
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                profilePhotoUrl: profilePhotoUrl
            )
            
            // Refresh the user profile in AuthViewModel so the app knows onboarding is complete
            await authViewModel?.fetchUserProfile()
            
            // Onboarding finished and profile refreshed!
            // The App entry point will automatically detect isOnboardingCompleted = true and show ContentView
            
        } catch {
            self.error = error
            self.showError = true
        }
        
        self.isLoading = false
    }
}
