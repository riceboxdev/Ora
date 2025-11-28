//
//  ChangeUsernameView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct ChangeUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ChangeUsernameViewModel
    private let currentUsername: String
    
    init(profileService: ProfileServiceProtocol, currentUsername: String) {
        self.currentUsername = currentUsername
        _viewModel = StateObject(wrappedValue: ChangeUsernameViewModel(
            profileService: profileService,
            currentUsername: currentUsername
        ))
    }
    
    var body: some View {
        List {
            Section(
                header: Text("Username")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                TextField("Username", text: $viewModel.username)
                    .font(.creatoDisplayBody())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if viewModel.isCheckingUsername {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking availability...")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.secondary)
                    }
                } else if !viewModel.username.isEmpty && viewModel.username != currentUsername {
                    if viewModel.isUsernameAvailable {
                        Label("Username available", systemImage: "checkmark.circle.fill")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.green)
                    } else if let error = viewModel.usernameError {
                        Label(error, systemImage: "xmark.circle.fill")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Requirements")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                    
                    RequirementRow(
                        text: "At least 3 characters",
                        isMet: viewModel.username.count >= 3
                    )
                    RequirementRow(
                        text: "No spaces",
                        isMet: viewModel.username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
                    )
                }
                .padding(.vertical, 4)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Change Username")
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
                    Task {
                        do {
                            try await viewModel.updateUsername()
                            dismiss()
                        } catch {
                            // Error is handled by viewModel.errorMessage
                        }
                    }
                }
                .font(.creatoDisplayBody())
                .disabled(!viewModel.canSave)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChangeUsernameView(
            profileService: ProfileService(),
            currentUsername: "currentuser"
        )
    }
}

