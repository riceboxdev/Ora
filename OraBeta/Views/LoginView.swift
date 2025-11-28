//
//  LoginView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var hasAppeared = false
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Title
            Image("oravectorcropped")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
                .padding(.bottom, 40)
                .foregroundStyle(.accent)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(isPulsing ? 1.05 : 0.95)
                .onAppear {
                    // Fade in
                    withAnimation(.easeIn(duration: 1.0)) {
                        hasAppeared = true
                    }
                    
                    // Start pulsing loop
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    // Handle Apple Sign In request
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    // Handle Apple Sign In completion
                    switch result {
                    case .success(let authResults):
                        print("Authorization successful: \(authResults)")
                        // TODO: Implement Apple Sign In with Firebase
                    case .failure(let error):
                        print("Authorization failed: \(error.localizedDescription)")
                        authViewModel.errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.white) // Or .black depending on theme
                .frame(height: 50)
                .clipShape(.capsule)
                
                // Sign in with Email
                Button(action: {
                    showEmailSignIn = true
                }) {
                    Text("Sign in with Email")
                        .font(.creatoDisplayBody())
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .foregroundColor(.whiteui)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding()
        .background(gridLines())
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
                .environmentObject(authViewModel)
                .presentationDetents([.medium])
        }
    }
    
    @ViewBuilder
    private func gridLines() -> some View {
        GridLinesView(
            resolution: .constant(15),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.2
        )
        .ignoresSafeArea()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}






















