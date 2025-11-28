//
//  OnboardingPreview.swift
//  OraBeta
//
//  Preview file for designing and testing OnboardingView in different states
//

import SwiftUI
import Combine

struct OnboardingPreview: View {
    @State private var selectedState: PreviewState = .usernameEmpty
    @State private var selectedStep: OnboardingStep = .emailVerification
    
    enum PreviewState: String, CaseIterable {
        case usernameEmpty = "Username - Empty"
        case usernameTyping = "Username - Typing"
        case usernameChecking = "Username - Checking"
        case usernameAvailable = "Username - Available"
        case usernameTaken = "Username - Taken"
        case usernameInvalid = "Username - Invalid"
        case profileSetupEmpty = "Profile - Empty"
        case profileSetupWithImage = "Profile - With Image"
        case profileSetupWithBio = "Profile - With Bio"
        case profileSetupComplete = "Profile - Complete"
        case welcomeReady = "Welcome - Ready"
        case welcomeLoading = "Welcome - Loading"
        case welcomeError = "Welcome - Error"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // State selector
                VStack(spacing: 12) {
                    Text("Onboarding Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Picker("Preview State", selection: $selectedState) {
                        ForEach(PreviewState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    
                    Picker("Onboarding Step", selection: $selectedStep) {
                        Text("Username").tag(OnboardingStep.username)
                        Text("Email Verification").tag(OnboardingStep.emailVerification)
                        Text("Profile Setup").tag(OnboardingStep.profileSetup)
                        Text("Welcome").tag(OnboardingStep.welcome)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                
                Divider()
                
                // Preview content
                ScrollView {
                    VStack(spacing: 20) {
                        previewContent
                            .padding()
                    }
                }
            }
        }
        .onChange(of: selectedState) { _ in
            updatePreviewState()
        }
        .onChange(of: selectedStep) { _ in
            updatePreviewState()
        }
    }
    
    @ViewBuilder
    private var previewContent: some View {
        switch selectedStep {
        case .username:
            UsernamePagePreview(state: selectedState)
        case .emailVerification:
            EmailVerificationPagePreview(state: selectedState)
        case .profileSetup:
            ProfileSetupPagePreview(state: selectedState)
        case .welcome:
            WelcomePagePreview(state: selectedState)
        }
    }
    
    private func updatePreviewState() {
        // This will be handled by the individual preview views
    }
}

// MARK: - Username Page Preview

struct UsernamePagePreview: View {
    let state: OnboardingPreview.PreviewState
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Username Page Preview")
                .font(.headline)
                .padding(.bottom)
            
            UsernamePage(viewModel: viewModel, navigationPath: .constant(NavigationPath()))
                .previewAuthenticated()
                .onAppear {
                    configureViewModel(for: state)
                }
        }
    }
    
    private func configureViewModel(for state: OnboardingPreview.PreviewState) {
        switch state {
        case .usernameEmpty:
            viewModel.username = ""
            viewModel.isUsernameAvailable = false
            viewModel.isCheckingUsername = false
            viewModel.usernameError = nil
        case .usernameTyping:
            viewModel.username = "test"
            viewModel.isUsernameAvailable = false
            viewModel.isCheckingUsername = false
            viewModel.usernameError = nil
        case .usernameChecking:
            viewModel.username = "testuser"
            viewModel.isUsernameAvailable = false
            viewModel.isCheckingUsername = true
            viewModel.usernameError = nil
        case .usernameAvailable:
            viewModel.username = "availableuser"
            viewModel.isUsernameAvailable = true
            viewModel.isCheckingUsername = false
            viewModel.usernameError = nil
        case .usernameTaken:
            viewModel.username = "takenuser"
            viewModel.isUsernameAvailable = false
            viewModel.isCheckingUsername = false
            viewModel.usernameError = "Username is already taken"
        case .usernameInvalid:
            viewModel.username = "ab"
            viewModel.isUsernameAvailable = false
            viewModel.isCheckingUsername = false
            viewModel.usernameError = "Username must be at least 3 characters"
        default:
            break
        }
    }
}

// MARK: - Email Verification Page Preview

struct EmailVerificationPagePreview: View {
    let state: OnboardingPreview.PreviewState
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Email Verification Page Preview")
                .font(.headline)
                .padding(.bottom)
            
            EmailVerificationPage(viewModel: viewModel, navigationPath: .constant(NavigationPath()))
                .onAppear {
                    configureViewModel(for: state)
                }
        }
    }
    
    private func configureViewModel(for state: OnboardingPreview.PreviewState) {
        // Email verification states can be configured here if needed
        // For now, just use default state
        switch state {
        default:
            break
        }
    }
}

// MARK: - Profile Setup Page Preview

struct ProfileSetupPagePreview: View {
    let state: OnboardingPreview.PreviewState
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile Setup Page Preview")
                .font(.headline)
                .padding(.bottom)
            
            ProfileSetupPage(viewModel: viewModel, navigationPath: .constant(NavigationPath()))
                .onAppear {
                    configureViewModel(for: state)
                }
        }
    }
    
    private func configureViewModel(for state: OnboardingPreview.PreviewState) {
        switch state {
        case .profileSetupEmpty:
            viewModel.selectedImage = nil
            viewModel.bio = ""
        case .profileSetupWithImage:
            viewModel.selectedImage = createPreviewImage()
            viewModel.bio = ""
        case .profileSetupWithBio:
            viewModel.selectedImage = nil
            viewModel.bio = "This is a test bio for preview purposes"
        case .profileSetupComplete:
            viewModel.selectedImage = createPreviewImage()
            viewModel.bio = "This is a complete profile with both image and bio"
        default:
            break
        }
    }
    
    private func createPreviewImage() -> UIImage? {
        // Create a simple colored image for preview
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text
            let text = "Preview"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Welcome Page Preview

struct WelcomePagePreview: View {
    let state: OnboardingPreview.PreviewState
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome Page Preview")
                .font(.headline)
                .padding(.bottom)
            
            WelcomePage(
                viewModel: viewModel,
                navigationPath: .constant(NavigationPath()),
                welcomeImages: []
            )
            .onAppear {
                configureViewModel(for: state)
            }
        }
    }
    
    private func configureViewModel(for state: OnboardingPreview.PreviewState) {
        switch state {
        case .welcomeReady:
            viewModel.isLoading = false
            viewModel.error = nil
        case .welcomeLoading:
            viewModel.isLoading = true
            viewModel.error = nil
        case .welcomeError:
            viewModel.isLoading = false
            viewModel.error = NSError(domain: "PreviewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Preview error message"])
            viewModel.showError = true
        default:
            break
        }
    }
}

// Note: We use the real OnboardingViewModel for previews
// The preview system configures the ViewModel state directly
// This requires Firebase to be configured, but provides accurate previews

// MARK: - Preview Provider

#Preview("Onboarding Preview - Full Flow") {
    OnboardingPreview()
}

#Preview("Username Page - Empty") {
    UsernamePagePreview(state: .usernameEmpty)
        .padding()
}

#Preview("Username Page - Available") {
    UsernamePagePreview(state: .usernameAvailable)
        .padding()
}

#Preview("Profile Setup - Complete") {
    ProfileSetupPagePreview(state: .profileSetupComplete)
        .padding()
}

#Preview("Welcome Page - Ready") {
    WelcomePagePreview(state: .welcomeReady)
        .padding()
}


