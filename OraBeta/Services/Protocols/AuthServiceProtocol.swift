//
//  AuthServiceProtocol.swift
//  OraBeta
//
//  Protocol for AuthService to enable testability and dependency injection
//

import Foundation
import FirebaseAuth
import Combine

/// Protocol defining the interface for authentication operations
protocol AuthServiceProtocol: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var isEmailVerified: Bool { get }
    
    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String?) async throws
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws
    
    /// Sign out
    func signOut() throws
    
    /// Get current user ID
    var userId: String? { get }
    
    /// Get current user email
    var userEmail: String? { get }
    
    /// Send email verification
    func sendEmailVerification() async throws
    
    /// Update user's email
    func updateEmail(newEmail: String) async throws
    
    /// Reload user to get latest auth state
    func reloadUser() async throws
    
    /// Change user's password
    func changePassword(currentPassword: String, newPassword: String) async throws
    
    /// Delete user account
    func deleteAccount() async throws
}

