//
//  AccountView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: AccountViewModel
    @State private var showChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var emailText = ""
    @State private var isEditingEmail = false
    @State private var emailError: String?
    @State private var isSavingEmail = false
    
    private let profileService = ProfileService()
    
    init() {
        let container = DIContainer.shared
        // Create AccountService on main actor
        let accountService = AccountService()
        _viewModel = StateObject(wrappedValue: AccountViewModel(
            authService: container.authService,
            profileService: container.profileService,
            accountService: accountService
        ))
    }
    
    var body: some View {
        List {
            // Account Information Section
            Section(
                header: Text("Account Information")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if let profile = viewModel.profile {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Email")
                                .font(.creatoDisplayBody())
                            Spacer()
                            
                            if isEditingEmail {
                                HStack(spacing: 8) {
                                    TextField("Email", text: $emailText)
                                        .font(.creatoDisplayBody())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .frame(maxWidth: 200)
                                    
                                    Button("Cancel") {
                                        emailText = profile.email
                                        isEditingEmail = false
                                        emailError = nil
                                    }
                                    .font(.creatoDisplayCaption())
                                    .foregroundColor(.secondary)
                                    
                                    Button("Save") {
                                        Task {
                                            await saveEmail()
                                        }
                                    }
                                    .font(.creatoDisplayCaption(.medium))
                                    .foregroundColor(.blue)
                                    .disabled(isSavingEmail || emailText.isEmpty || emailText == profile.email)
                                    
                                    if isSavingEmail {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Text(profile.email)
                                        .font(.creatoDisplayBody())
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        emailText = profile.email
                                        isEditingEmail = true
                                        emailError = nil
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Email verification status and button - shown below email field
                        if !isEditingEmail {
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if !viewModel.isEmailVerified {
                                        Button("Verify Email") {
                                            Task {
                                                await viewModel.sendVerificationEmail()
                                                // Reload after a delay to check if verified
                                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                                await viewModel.reloadUser()
                                            }
                                        }
                                        .font(.creatoDisplayCaption())
                                        .foregroundColor(.blue)
                                        
                                        if viewModel.showEmailSentConfirmation {
                                            HStack(spacing: 8) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                Text("Verification email sent!")
                                                    .font(.creatoDisplayCaption(.medium))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                            Text("Verified")
                                                .font(.creatoDisplayCaption())
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let error = emailError {
                            Text(error)
                                .font(.creatoDisplayCaption())
                                .foregroundColor(.red)
                        }
                    }
                    
                    NavigationLink {
                        ChangeUsernameView(
                            profileService: profileService,
                            currentUsername: profile.username
                        )
                        .onDisappear {
                            Task {
                                await viewModel.loadProfile()
                            }
                        }
                    } label: {
                        HStack {
                            Text("Username")
                                .font(.creatoDisplayBody())
                            Spacer()
                            Text(profile.username)
                                .font(.creatoDisplayBody())
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Account Created")
                            .font(.creatoDisplayBody())
                        Spacer()
                        Text(profile.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("User ID")
                            .font(.creatoDisplayBody())
                        Spacer()
                        Text(profile.id ?? "Unknown")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                } else if viewModel.isLoading {
                    HStack {
                        Text("Loading...")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Security Section
            Section(
                header: Text("Security")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if viewModel.hasEmailPassword {
                    Button(action: {
                        showChangePassword = true
                    }) {
                        HStack {
                            Text("Change Password")
                                .font(.creatoDisplayBody())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                HStack {
                    Text("Connected Accounts")
                        .font(.creatoDisplayBody())
                    Spacer()
                    Text(viewModel.connectedProviders.joined(separator: ", "))
                        .font(.creatoDisplayBody())
                        .foregroundColor(.secondary)
                }
            }
            
            // Account Actions Section
            Section(
                header: Text("Account Actions")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
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
                
                Button(action: {
                    viewModel.requestDeleteAccount()
                }) {
                    HStack {
                        Spacer()
                        Text("Delete Account")
                            .font(.creatoDisplayBody(.medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
            if let profile = viewModel.profile {
                emailText = profile.email
            }
        }
        .onChange(of: viewModel.profile?.email) { newEmail in
            if let newEmail = newEmail, !isEditingEmail {
                emailText = newEmail
            }
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(
                currentPassword: $currentPassword,
                newPassword: $newPassword,
                confirmPassword: $confirmPassword,
                passwordError: $passwordError,
                onChangePassword: { current, new in
                    do {
                        try await viewModel.changePassword(currentPassword: current, newPassword: new)
                        showChangePassword = false
                        currentPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                    } catch {
                        passwordError = error.localizedDescription
                    }
                }
            )
        }
        .alert("Delete Account", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveEmail() async {
        guard !emailText.isEmpty else {
            emailError = "Email cannot be empty"
            return
        }
        
        // Basic email validation
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: emailText) else {
            emailError = "Please enter a valid email address"
            return
        }
        
        isSavingEmail = true
        emailError = nil
        
        do {
            try await viewModel.changeEmail(newEmail: emailText)
            isEditingEmail = false
            // Email will be reloaded via loadProfile in changeEmail
            // Update emailText to match the new profile email
            if let updatedProfile = viewModel.profile {
                emailText = updatedProfile.email
            }
        } catch {
            emailError = error.localizedDescription
        }
        
        isSavingEmail = false
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    @Binding var passwordError: String?
    let onChangePassword: (String, String) async throws -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(
                    header: Text("Current Password")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    SecureField("Current Password", text: $currentPassword)
                        .font(.creatoDisplayBody())
                }
                
                Section(
                    header: Text("New Password")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    SecureField("New Password", text: $newPassword)
                        .font(.creatoDisplayBody())
                    SecureField("Confirm Password", text: $confirmPassword)
                        .font(.creatoDisplayBody())
                }
                
                if let error = passwordError {
                    Section {
                        Text(error)
                            .font(.creatoDisplayBody())
                            .foregroundColor(.red)
                    }
                }
            }
            .settingsListStyle()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.creatoDisplayBody())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !currentPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
                            passwordError = "All fields are required"
                            return
                        }
                        
                        guard newPassword == confirmPassword else {
                            passwordError = "Passwords do not match"
                            return
                        }
                        
                        guard newPassword.count >= 6 else {
                            passwordError = "Password must be at least 6 characters"
                            return
                        }
                        
                        Task {
                            isLoading = true
                            passwordError = nil
                            do {
                                try await onChangePassword(currentPassword, newPassword)
                                dismiss()
                            } catch {
                                passwordError = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                    .font(.creatoDisplayBody())
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
            .environmentObject(AuthViewModel())
    }
}
