//
//  AuthService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import Combine

class AuthService: AuthServiceProtocol {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Listen to authentication state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
            self?.isCheckingAuth = false
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // Sign up with email and password
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name if provided
        if let displayName = displayName, !displayName.isEmpty {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    // Sign out
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // Get current user ID
    var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Get current user email
    var userEmail: String? {
        return Auth.auth().currentUser?.email
    }
    
    // Check if email is verified
    var isEmailVerified: Bool {
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }
    
    // Send email verification
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.sendEmailVerification()
    }
    
    // Update user's email
    func updateEmail(newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.updateEmail(to: newEmail)
    }
    
    // Reload user to get latest auth state
    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.reload()
    }
    
    // Change user's password
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        // Re-authenticate with current password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        
        // Update password
        try await user.updatePassword(to: newPassword)
    }
    
    // Delete user account
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.delete()
    }
}






















