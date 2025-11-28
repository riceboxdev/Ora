//
//  AccountViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AccountViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isEmailVerified: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDeleting: Bool = false
    @Published var showEmailSentConfirmation: Bool = false
    
    private let authService: AuthServiceProtocol
    private let profileService: ProfileServiceProtocol
    private let accountService: AccountService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        accountService: AccountService
    ) {
        self.authService = authService
        self.profileService = profileService
        self.accountService = accountService
        
        // Observe auth service user changes
        if let authService = authService as? AuthService {
            authService.$currentUser
                .sink { [weak self] user in
                    Task { @MainActor [weak self] in
                        await self?.updateEmailVerificationStatus()
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Load Data
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            profile = try await profileService.getCurrentUserProfile()
            await updateEmailVerificationStatus()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to load profile: \(error)")
        }
        
        isLoading = false
    }
    
    func updateEmailVerificationStatus() async {
        isEmailVerified = authService.isEmailVerified
    }
    
    // MARK: - Email Verification
    
    func sendVerificationEmail() async {
        isLoading = true
        errorMessage = nil
        showEmailSentConfirmation = false
        
        do {
            try await authService.sendEmailVerification()
            print("✅ AccountViewModel: Verification email sent")
            showEmailSentConfirmation = true
            // Hide confirmation after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showEmailSentConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to send verification email: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Email Change
    
    func changeEmail(newEmail: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Update email in Firebase Auth
            try await authService.updateEmail(newEmail: newEmail)
            
            // Update email in Firestore profile
            if let userId = authService.userId {
                try await profileService.updateProfile(
                    userId: userId,
                    fields: ["email": newEmail]
                )
            }
            
            // Reload profile to get updated email
            await loadProfile()
            
            print("✅ AccountViewModel: Email changed successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to change email: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    func reloadUser() async {
        do {
            try await authService.reloadUser()
            await updateEmailVerificationStatus()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to reload user: \(error)")
        }
    }
    
    // MARK: - Password Change
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            print("✅ AccountViewModel: Password changed successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to change password: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Account Deletion
    
    func requestDeleteAccount() {
        showDeleteConfirmation = true
    }
    
    func deleteAccount() async {
        guard let userId = authService.userId else {
            errorMessage = "Not authenticated"
            return
        }
        
        isDeleting = true
        errorMessage = nil
        
        do {
            // First, delete all user data from Firestore
            print("🗑️ AccountViewModel: Deleting all user data...")
            try await accountService.deleteAllUserData(userId: userId)
            
            // Then, delete the Firebase Auth account
            print("🗑️ AccountViewModel: Deleting Firebase Auth account...")
            try await authService.deleteAccount()
            
            print("✅ AccountViewModel: Account deleted successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ AccountViewModel: Failed to delete account: \(error)")
        }
        
        isDeleting = false
        showDeleteConfirmation = false
    }
    
    // MARK: - Connected Accounts
    
    var connectedProviders: [String] {
        guard let user = authService.currentUser else { return [] }
        var providers: [String] = []
        
        if user.providerData.contains(where: { $0.providerID == "password" }) {
            providers.append("Email")
        }
        
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            providers.append("Apple")
        }
        
        return providers
    }
    
    var hasEmailPassword: Bool {
        connectedProviders.contains("Email")
    }
}

