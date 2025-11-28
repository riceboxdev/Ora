//
//  PreviewHelpers.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/10/25.
//

import SwiftUI
import FirebaseAuth

struct PreviewAuthenticated: ViewModifier {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isAuthenticating = true
    private let email: String
    private let password: String
    private let username: String
    
    init(email: String = "preview@oratest.com", password: String = "preview123", username: String = "previewuser") {
        self.email = email
        self.password = password
        self.username = username
    }
    
    func body(content: Content) -> some View {
        Group {
            if isAuthenticating {
                VStack {
                    ProgressView("Authenticating preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                content
                    .environmentObject(authViewModel)
            }
        }
        .task {
            await authenticatePreviewUser()
        }
    }
    
    private func authenticatePreviewUser() async {
        do {
            // Try to sign in with provided credentials
            // First try to sign in
            do {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                print("✅ Preview: Signed in as \(result.user.email ?? "unknown")")
            } catch {
                // If user doesn't exist, create it
                print("⚠️ Preview: User doesn't exist, creating...")
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                print("✅ Preview: Created user \(result.user.email ?? "unknown")")
                
                // Create profile in Firestore
                let profile = UserProfile(
                    id: result.user.uid,
                    email: email,
                    username: username,
                    bio: "Preview user for testing",
                    isAdmin: false
                )
                
                let profileService = ProfileService()
                try await profileService.saveUserProfile(profile)
                print("✅ Preview: Created profile for user")
            }
            
            // Wait a moment for AuthViewModel to update
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
        } catch {
            print("❌ Preview: Authentication failed: \(error.localizedDescription)")
        }
        
        isAuthenticating = false
    }
}

struct PreviewAdmin: ViewModifier {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isAuthenticating = true
    private let email: String
    private let password: String
    private let username: String
    
    init(email: String = "admin@oratest.com", password: String = "admin123", username: String = "admin") {
        self.email = email
        self.password = password
        self.username = username
    }
    
    func body(content: Content) -> some View {
        Group {
            if isAuthenticating {
                VStack {
                    ProgressView("Authenticating admin preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                content
                    .environmentObject(authViewModel)
            }
        }
        .task {
            await authenticateAdminUser()
        }
    }
    
    private func authenticateAdminUser() async {
        do {
            // Try to sign in with provided admin credentials
            // First try to sign in
            do {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                print("✅ Preview: Signed in as admin \(result.user.email ?? "unknown")")
            } catch {
                // If admin doesn't exist, create it
                print("⚠️ Preview: Admin user doesn't exist, creating...")
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                print("✅ Preview: Created admin user \(result.user.email ?? "unknown")")
                
                // Create admin profile in Firestore
                let profile = UserProfile(
                    id: result.user.uid,
                    email: email,
                    username: username,
                    bio: "Preview admin for testing",
                    isAdmin: true
                )
                
                let profileService = ProfileService()
                try await profileService.saveUserProfile(profile)
                print("✅ Preview: Created admin profile for user")
            }
            
            // Wait a moment for AuthViewModel to update
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
        } catch {
            print("❌ Preview: Admin authentication failed: \(error.localizedDescription)")
        }
        
        isAuthenticating = false
    }
}

extension View {
    /// Preview the view with a real authenticated Firebase user
    /// This will create/sign in a test user in Firebase with the provided credentials
    /// - Parameters:
    ///   - email: The email to use for authentication (default: "preview@oratest.com")
    ///   - password: The password to use for authentication (default: "preview123")
    ///   - username: The username to use for the profile (default: "previewuser")
    func previewAuthenticated(
        email: String = "preview@oratest.com",
        password: String = "preview123",
        username: String = "previewuser"
    ) -> some View {
        modifier(PreviewAuthenticated(email: email, password: password, username: username))
    }
    
    /// Preview the view with a real authenticated admin user
    /// This will create/sign in a test admin user in Firebase with the provided credentials
    /// - Parameters:
    ///   - email: The admin email to use for authentication (default: "admin@oratest.com")
    ///   - password: The admin password to use for authentication (default: "admin123")
    ///   - username: The admin username to use for the profile (default: "admin")
    func previewAdmin(
        email: String = "admin@oratest.com",
        password: String = "admin123",
        username: String = "admin"
    ) -> some View {
        modifier(PreviewAdmin(email: email, password: password, username: username))
    }
}

// MARK: - Preview User Profiles

extension UserProfile {
    static let previewUser = UserProfile(
        id: "preview-user",
        email: "preview@example.com",
        username: "previewuser",
        bio: "This is a preview user for testing",
        profilePhotoUrl: "https://picsum.photos/seed/preview/200/200.jpg",
        isAdmin: false
    )
    
    static let previewAdmin = UserProfile(
        id: "admin-user",
        email: "admin@example.com",
        username: "admin",
        bio: "This is a preview admin for testing",
        profilePhotoUrl: "https://picsum.photos/seed/admin/200/200.jpg",
        isAdmin: true
    )
}

// MARK: - Preview Posts

extension Post {
    static let previewPost = Post(
        activityId: "preview-post",
        userId: "preview-user",
        username: "previewuser",
        userProfilePhotoUrl: "https://picsum.photos/seed/preview/200/200.jpg",
        imageUrl: "https://picsum.photos/seed/post/400/600.jpg",
        imageWidth: 400,
        imageHeight: 600,
        caption: "This is a preview post for testing the UI",
        likeCount: 42,
        commentCount: 8,
        viewCount: 150,
        shareCount: 5,
        saveCount: 12,
        createdAt: Date()
    )
}
