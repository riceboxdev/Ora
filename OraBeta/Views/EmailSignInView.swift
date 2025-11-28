//
//  EmailSignInView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct EmailSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Spacer()
                // Email Field
                OraTextField(
                    placeholder: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                
                // Display Name Field (only for sign up)
                if isSignUp {
                    OraTextField(
                        placeholder: "Display Name",
                        text: $displayName,
                        autocapitalization: .words,
                        textContentType: .name
                    )
                }
                
                // Password Field
                OraTextField(
                    placeholder: "Password",
                    text: $password,
                    textContentType: isSignUp ? .newPassword : .password,
                    isSecure: true
                )
                
                // Error Message
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Sign In/Sign Up Button
                Button(action: {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                displayName: displayName.isEmpty ? nil : displayName
                            )
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                        // Dismiss logic is handled by auth state change in parent view, 
                        // but we can also dismiss if successful if needed. 
                        // For now, rely on parent state change or manual dismiss if needed.
                    }
                }) {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
//                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .buttonStyle(.glassProminent)
                
                // Toggle Sign In/Sign Up
                Button(action: {
                    isSignUp.toggle()
                    authViewModel.errorMessage = nil
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EmailSignInView()
        .environmentObject(AuthViewModel())
}
