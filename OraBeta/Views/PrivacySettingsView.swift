//
//  PrivacySettingsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct PrivacySettingsView: View {
    private let blockedUsersService = BlockedUsersService()
    private let visibilityService = AccountVisibilityService()
    private let accountService = AccountService()
    
    @State private var blockedUsers: [BlockedUser] = []
    @State private var accountSettings: AccountSettings?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showUnblockConfirmation: BlockedUser?
    @State private var isExporting = false
    
    var body: some View {
        List {
            // Blocked Users Section
            Section(
                header: Text("Blocked Users")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if isLoading {
                    HStack {
                        Text("Loading...")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else if blockedUsers.isEmpty {
                    Text("No blocked users")
                        .font(.creatoDisplayBody())
                        .foregroundColor(.secondary)
                } else {
                    ForEach(blockedUsers) { blockedUser in
                        BlockedUserRow(
                            blockedUser: blockedUser,
                            onUnblock: {
                                showUnblockConfirmation = blockedUser
                            }
                        )
                    }
                }
            }
            
            // Account Visibility Section
            Section(
                header: Text("Account Visibility")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if let settings = accountSettings {
                    Picker("Account Visibility", selection: Binding(
                        get: { settings.accountVisibility },
                        set: { newValue in
                            Task {
                                do {
                                    try await visibilityService.updateAccountVisibility(newValue)
                                    await loadSettings()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    )) {
                        Text("Public").tag("public")
                        Text("Private").tag("private")
                    }
                    .font(.creatoDisplayBody())
                    
                    Picker("Profile Visibility", selection: Binding(
                        get: { settings.profileVisibility },
                        set: { newValue in
                            Task {
                                do {
                                    try await visibilityService.updateProfileVisibility(newValue)
                                    await loadSettings()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    )) {
                        Text("Public").tag("public")
                        Text("Private").tag("private")
                    }
                    .font(.creatoDisplayBody())
                    
                    Picker("Content Visibility", selection: Binding(
                        get: { settings.contentVisibility },
                        set: { newValue in
                            Task {
                                do {
                                    try await visibilityService.updateContentVisibility(newValue)
                                    await loadSettings()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    )) {
                        Text("Public").tag("public")
                        Text("Private").tag("private")
                    }
                    .font(.creatoDisplayBody())
                }
            }
            
            // Data Export Section
            Section(
                header: Text("Data Export")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                Button(action: {
                    Task {
                        await exportData()
                    }
                }) {
                    HStack {
                        Text("Export My Data")
                            .font(.creatoDisplayBody())
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .disabled(isExporting)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .alert("Unblock User", isPresented: Binding(
            get: { showUnblockConfirmation != nil },
            set: { if !$0 { showUnblockConfirmation = nil } }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .destructive) {
                if let user = showUnblockConfirmation {
                    Task {
                        await unblockUser(user)
                    }
                }
            }
        } message: {
            if let user = showUnblockConfirmation {
                Text("Are you sure you want to unblock this user?")
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            blockedUsers = try await blockedUsersService.getBlockedUsers()
            await loadSettings()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PrivacySettingsView: Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadSettings() async {
        do {
            accountSettings = try await visibilityService.getAccountSettings()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PrivacySettingsView: Failed to load settings: \(error)")
        }
    }
    
    private func unblockUser(_ blockedUser: BlockedUser) async {
        do {
            try await blockedUsersService.unblockUser(blockedId: blockedUser.blockedId)
            // Invalidate cache to ensure immediate effect
            blockedUsersService.invalidateCache()
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PrivacySettingsView: Failed to unblock user: \(error)")
        }
    }
    
    private func exportData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            return
        }
        
        isExporting = true
        errorMessage = nil
        
        do {
            let exportData = try await accountService.exportUserData(userId: userId)
            
            // Convert to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            
            // Save to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ora_export_\(Date().timeIntervalSince1970).json")
            try jsonData.write(to: tempURL)
            
            // Share via system share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PrivacySettingsView: Failed to export data: \(error)")
        }
        
        isExporting = false
    }
}

struct BlockedUserRow: View {
    let blockedUser: BlockedUser
    let onUnblock: () -> Void
    
    @State private var profile: UserProfile?
    
    var body: some View {
        HStack {
            if let profile = profile {
                AsyncImage(url: URL(string: profile.profilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.username)
                        .font(.creatoDisplayBody())
                    if let reason = blockedUser.reason {
                        Text(reason)
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Loading...")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onUnblock) {
                Text("Unblock")
                    .font(.creatoDisplayCaption())
                    .foregroundColor(.blue)
            }
        }
        .task {
            do {
                profile = try await ProfileService().getUserProfile(userId: blockedUser.blockedId)
            } catch {
                print("❌ BlockedUserRow: Failed to load profile: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}

