//
//  ChangeUsernameViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class ChangeUsernameViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameAvailable: Bool = false
    @Published var isCheckingUsername: Bool = false
    @Published var usernameError: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let profileService: ProfileServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let currentUsername: String
    
    init(profileService: ProfileServiceProtocol, currentUsername: String) {
        self.profileService = profileService
        self.currentUsername = currentUsername
        self.username = currentUsername
        
        setupUsernameValidation()
    }
    
    // MARK: - Username Validation
    
    private func setupUsernameValidation() {
        $username
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] username in
                guard let self = self else { return }
                if !username.isEmpty && username != self.currentUsername {
                    Task {
                        await self.checkUsername(username)
                    }
                } else if username == self.currentUsername {
                    self.isUsernameAvailable = false
                    self.usernameError = nil
                } else {
                    self.isUsernameAvailable = false
                    self.usernameError = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkUsername(_ username: String) async {
        // Basic validation
        guard username.count >= 3 else {
            self.usernameError = "Username must be at least 3 characters"
            self.isUsernameAvailable = false
            return
        }
        
        guard username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            self.usernameError = "Username cannot contain spaces"
            self.isUsernameAvailable = false
            return
        }
        
        self.isCheckingUsername = true
        self.usernameError = nil
        
        do {
            // Check availability via service
            let isAvailable = try await profileService.checkUsernameAvailability(username: username)
            self.isUsernameAvailable = isAvailable
            if !isAvailable {
                self.usernameError = "Username is already taken"
            }
        } catch {
            self.usernameError = "Error checking availability"
            print("❌ ChangeUsernameViewModel: Error checking username: \(error)")
        }
        
        self.isCheckingUsername = false
    }
    
    // MARK: - Actions
    
    func updateUsername() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ChangeUsernameViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard !username.isEmpty else {
            throw NSError(domain: "ChangeUsernameViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty"])
        }
        
        guard username.count >= 3 else {
            throw NSError(domain: "ChangeUsernameViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username must be at least 3 characters"])
        }
        
        guard username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw NSError(domain: "ChangeUsernameViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username cannot contain spaces"])
        }
        
        guard isUsernameAvailable else {
            throw NSError(domain: "ChangeUsernameViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username is not available"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await profileService.updateProfile(userId: userId, fields: ["username": username])
            print("✅ ChangeUsernameViewModel: Username updated successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ ChangeUsernameViewModel: Failed to update username: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    var canSave: Bool {
        !username.isEmpty &&
        username.count >= 3 &&
        username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil &&
        isUsernameAvailable &&
        username != currentUsername &&
        !isLoading
    }
}

