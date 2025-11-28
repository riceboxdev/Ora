//
//  SettingsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    private let profileService = ProfileService()
    @State private var profile: UserProfile?
    @State private var isEmailVerified: Bool = false
    @State private var isSendingVerificationEmail: Bool = false
    @State private var showEmailSentConfirmation: Bool = false
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section(
                    header: Text("Profile")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    if let profile {
                        NavigationLink {
                            EditProfileView(profile: profile, profileService: profileService)
                                .onDisappear {
                                    // Reload profile when navigating back from EditProfileView
                                    Task {
                                        await loadProfile()
                                    }
                                }
                        } label: {
                            Text("Edit Profile")
                                .font(.creatoDisplayBody())
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        HStack {
                            Text("Edit Profile")
                                .font(.creatoDisplayBody())
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                
                // Account Section
                Section(
                    header: Text("Account")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: AccountView()) {
                        Text("Account")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                    
                    if !isEmailVerified {
                        Button(action: {
                            Task {
                                await sendVerificationEmail()
                            }
                        }) {
                            HStack {
                                if isSendingVerificationEmail {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "envelope.badge")
                                        .foregroundColor(.accentColor)
                                }
                                Text("Verify Email")
                                    .font(.creatoDisplayBody())
                                    .foregroundColor(.accentColor)
                                Spacer()
                            }
                        }
                        .disabled(isSendingVerificationEmail)
                        
                        if showEmailSentConfirmation {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Verification email sent!")
                                    .font(.creatoDisplayCaption(.medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    NavigationLink(destination: AdminDashboardView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Admin Dashboard")
                                    .font(.creatoDisplayBody())
                                    .foregroundColor(.accentColor)
                                Text("Advanced tools")
                                    .font(.creatoDisplayCaption())
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.shield")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Notifications Section
                Section(
                    header: Text("Notifications")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Text("Notifications")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Privacy Section
                Section(
                    header: Text("Privacy")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: PrivacySettingsView()) {
                        Text("Privacy")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Preferences Section
                Section(
                    header: Text("Preferences")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: PreferencesView()) {
                        Text("Preferences")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                }

                // About Section
                Section(
                    header: Text("About")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: AboutOraView()) {
                        Text("About Ora")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                    NavigationLink(destination: TermsAndPrivacyView()) {
                        Text("Terms & Privacy")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                }

                // Help & Feedback Section
                Section(
                    header: Text("Help & Feedback")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    NavigationLink(destination: ReportedPostsView()) {
                        Text("My Reports")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                    NavigationLink(destination: HelpSupportView()) {
                        Text("Help & Support")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                    NavigationLink(destination: SendFeedbackView()) {
                        Text("Send Feedback")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .font(.creatoDisplayBody(.medium))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .settingsListStyle()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tabBarMinimizeBehavior(.onScrollDown)
            .task {
                await loadProfile()
                await checkEmailVerificationStatus()
            }
        }
    }
    
    private func loadProfile() async {
        print("📝 SettingsView: Loading profile...")
        do {
            profile = try await profileService.getCurrentUserProfile()
            
            if let profile = profile {
                print("✅ SettingsView: Profile loaded")
                print("   ID: \(profile.id ?? "nil")")
                print("   Username: \(profile.username)")
                print("   Email: \(profile.email)")
            } else {
                print("⚠️ SettingsView: Profile is nil, attempting to create...")
                // If profile doesn't exist, try to create it
                do {
                    try await profileService.createProfileForCurrentUser()
                    profile = try await profileService.getCurrentUserProfile()
                    if let profile = profile {
                        print("✅ SettingsView: New profile created")
                        print("   ID: \(profile.id ?? "nil")")
                        print("   Username: \(profile.username)")
                    }
                } catch {
                    print("❌ SettingsView: Failed to create profile: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ SettingsView: Error loading profile: \(error)")
        }
    }
    
    private func checkEmailVerificationStatus() async {
        let container = DIContainer.shared
        isEmailVerified = container.authService.isEmailVerified
    }
    
    private func sendVerificationEmail() async {
        isSendingVerificationEmail = true
        showEmailSentConfirmation = false
        
        let container = DIContainer.shared
        do {
            try await container.authService.sendEmailVerification()
            showEmailSentConfirmation = true
            // Hide confirmation after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showEmailSentConfirmation = false
            // Reload verification status
            await checkEmailVerificationStatus()
        } catch {
            print("❌ SettingsView: Failed to send verification email: \(error.localizedDescription)")
        }
        
        isSendingVerificationEmail = false
    }
}

// MARK: - Settings Detail Screens

/// Simple about screen showing app name and version information.
struct AboutOraView: View {
    
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
        "Ora"
    }
    
    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appName)
                        .font(.creatoDisplayTitle())
                    Text(versionString)
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                Text("Ora is a place to discover and share inspiring visual stories. More detailed about content can go here later.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
        }
        .settingsListStyle()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Placeholder for Terms of Service / Privacy Policy.
struct TermsAndPrivacyView: View {
    
    var body: some View {
        List {
            Section {
                Text("Terms of Service")
                    .font(.creatoDisplayHeadline())
                Text("Privacy Policy")
                    .font(.creatoDisplayHeadline())
            }
            
            Section {
                Text("Links to the full Terms of Service and Privacy Policy will appear here. For now, this is a placeholder.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
        }
        .settingsListStyle()
        .navigationTitle("Terms & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Placeholder help/support screen.
struct HelpSupportView: View {
    
    var body: some View {
        List {
            Section {
                Text("Help Center")
                    .font(.creatoDisplayBody())
                Text("FAQ")
                    .font(.creatoDisplayBody())
            }
            
            Section {
                Text("Help content and links to support resources will be added here in a future update.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
        }
        .settingsListStyle()
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Placeholder feedback screen.
struct SendFeedbackView: View {
    
    var body: some View {
        List {
            Section(header: Text("We’d love your feedback").font(.creatoDisplayCaption(.medium))) {
                Text("Tell us what you think about Ora, what’s working well, and what could be improved.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
            
            Section {
                Text("In a future update, this will open an in-app feedback form or your email client to contact us directly.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
        }
        .settingsListStyle()
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .previewAuthenticated()
}

#Preview("Admin Settings") {
    SettingsView()
        .previewAdmin()
}

