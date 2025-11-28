//
//  OnboardingView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import SwiftUI
import UIKit

enum OnboardingStep: Hashable {
    case username
    case emailVerification
    case profileSetup
    case welcome
}

// MARK: - Step Counter Components

/// Step counter style options - change this to switch between styles
/// 
/// Available styles:
/// - `.dots`: Dots with current step highlighted (larger, animated)
/// - `.progressBar`: Progress bar with "Step X of 3" text below
/// - `.numbered`: Simple "Step X of 3" text centered
/// - `.minimal`: Small minimal dots
enum StepCounterStyle {
    case dots           // Version 1: Dots with current step highlighted
    case progressBar   // Version 2: Progress bar
    case numbered      // Version 3: "Step X of 3" text
    case minimal       // Version 4: Minimal dots
}

// ⚙️ CHANGE THIS TO SWITCH BETWEEN STEP COUNTER STYLES ⚙️
// Options: .dots, .progressBar, .numbered, .minimal
let currentStepCounterStyle: StepCounterStyle = .progressBar

struct StepCounterView: View {
    let currentStep: Int
    let totalSteps: Int
    let style: StepCounterStyle
    
    init(currentStep: Int, totalSteps: Int = 3, style: StepCounterStyle = currentStepCounterStyle) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .dots:
            dotsStyle
        case .progressBar:
            progressBarStyle
        case .numbered:
            numberedStyle
        case .minimal:
            minimalStyle
        }
    }
    
    // Version 1: Dots with current step highlighted
    private var dotsStyle: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.primary : Color.primary.opacity(0.2))
                    .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // Version 2: Progress bar
    private var progressBarStyle: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.primary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.creatoDisplayCaption())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // Version 3: "Step X of 3" text
    private var numberedStyle: some View {
        HStack {
            Spacer()
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.creatoDisplayCaption(.medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // Version 4: Minimal dots
    private var minimalStyle: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.primary : Color.primary.opacity(0.15))
                    .frame(width: 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: OnboardingViewModel
    @StateObject private var welcomeImageService = WelcomeImageService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var emailVerificationCompleted = false
    
    init() {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Show username as root if email is verified, otherwise show email verification
            if emailVerificationCompleted {
            UsernamePage(viewModel: viewModel, navigationPath: $navigationPath)
                .navigationDestination(for: OnboardingStep.self) { step in
                    Group {
                        switch step {
                        case .username:
                            UsernamePage(viewModel: viewModel, navigationPath: $navigationPath)
                            case .emailVerification:
                                // Never allow navigation back to email verification
                                UsernamePage(viewModel: viewModel, navigationPath: $navigationPath)
                        case .profileSetup:
                            ProfileSetupPage(viewModel: viewModel, navigationPath: $navigationPath)
                        case .welcome:
                                WelcomePage(
                                    viewModel: viewModel,
                                    navigationPath: $navigationPath,
                                    welcomeImages: welcomeImageService.images
                                )
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                    .navigationBarBackButtonHidden(true)
            } else {
                EmailVerificationPage(viewModel: viewModel, navigationPath: $navigationPath)
                    .navigationDestination(for: OnboardingStep.self) { step in
                        Group {
                            switch step {
                            case .username:
                                UsernamePage(viewModel: viewModel, navigationPath: $navigationPath)
                            case .emailVerification:
                                EmailVerificationPage(viewModel: viewModel, navigationPath: $navigationPath)
                            case .profileSetup:
                                ProfileSetupPage(viewModel: viewModel, navigationPath: $navigationPath)
                            case .welcome:
                                WelcomePage(
                                    viewModel: viewModel,
                                    navigationPath: $navigationPath,
                                    welcomeImages: welcomeImageService.images
                                )
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
            }
        }
        .onChange(of: viewModel.isEmailVerified) { isVerified in
            if isVerified && !emailVerificationCompleted {
                emailVerificationCompleted = true
                // Clear navigation path and set username as new root
                navigationPath = NavigationPath()
            }
        }
        .onAppear {
            // Inject authViewModel when view appears
            viewModel.setAuthViewModel(authViewModel)
            
            // Check email verification status synchronously first to avoid showing wrong screen
            // This prevents the flash of email verification page when email is already verified
            viewModel.checkEmailVerificationStatusSync()
            if viewModel.isEmailVerified {
                emailVerificationCompleted = true
                navigationPath = NavigationPath()
            }
            
            // Then reload user to get latest verification status (in case it changed)
            Task {
                await viewModel.checkEmailVerificationStatus()
                // Update state if email verification status changed
                if viewModel.isEmailVerified && !emailVerificationCompleted {
                    await MainActor.run {
                        emailVerificationCompleted = true
                        navigationPath = NavigationPath()
                    }
                }
            }
            
            // Fetch and preload welcome images early so they're ready for the welcome screen
            Task {
                await welcomeImageService.fetchImages()
                // Preload images into cache so they're ready when welcome screen appears
                await welcomeImageService.preloadImages()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
    }
    
}

// MARK: - Subviews

struct UsernamePage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ZStack {
            // Grid lines background
            gridLinesBackground()
            
            // Content
        VStack(spacing: 20) {
            // Step counter
            StepCounterView(currentStep: 2, totalSteps: 3)
            
            Spacer()
            
            Text("Choose a username")
                .font(.creatoDisplayTitle())
                .padding(.horizontal)
                .hLeading()
            
            VStack(alignment: .leading, spacing: 8) {
                RequirementRow(
                    text: "At least 3 characters",
                    isMet: viewModel.meetsMinLength
                )
                RequirementRow(
                    text: "No spaces",
                    isMet: viewModel.hasNoSpaces
                )
            }
            .padding(.horizontal)
            .hLeading()
            
            TextField("Username", text: $viewModel.username)
                .font(.creatoDisplayHeadline(.regular))
                .padding(.horizontal)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal)
            
            if viewModel.isCheckingUsername {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.horizontal)
            } else if !viewModel.username.isEmpty {
                if viewModel.isUsernameAvailable {
                    Label("Username available", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(.horizontal)
                } else if let error = viewModel.usernameError {
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
        
            Spacer()
            
            Button(action: {
                navigationPath.append(OnboardingStep.profileSetup)
            }) {
                Text("Next")
                    .font(.creatoDisplayHeadline())
                    .foregroundColor(.whiteui)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.isUsernameAvailable)
            .padding()
        }
        }
    }
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(0.3), location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}

struct ProfileSetupPage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Binding var navigationPath: NavigationPath
    @StateObject private var welcomeImageService = WelcomeImageService.shared
    @State private var showImagePicker = false
    @State private var displayImage: UIImage?
    @State private var imageProcessingTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Grid lines background
            gridLinesBackground()
            
            // Content
        VStack(spacing: 20) {
            // Step counter
            StepCounterView(currentStep: 3, totalSteps: 3)
            
            Spacer()
            
            Text("Set up your profile")
                .font(.creatoDisplayTitle())
                .padding(.horizontal)
            
            Button(action: { showImagePicker = true }) {
                ZStack {
                    if let image = displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                // Process initial image if it exists
                if let image = viewModel.selectedImage {
                    processImage(image)
                }
            }
            .onChange(of: viewModel.selectedImage) { newImage in
                // Cancel any existing image processing task
                imageProcessingTask?.cancel()
                
                // Process new image
                if let image = newImage {
                    processImage(image)
                } else {
                    displayImage = nil
                }
            }
            .onDisappear {
                // Cancel image processing when view disappears
                imageProcessingTask?.cancel()
            }
            
            TextField("Display Name (Optional)", text: $viewModel.displayName)
                .font(.creatoDisplayHeadline(.regular))
                .padding(.horizontal)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .textContentType(.name)
                .autocapitalization(.words)
                .padding(.horizontal)
            
            TextField("Bio (Optional)", text: $viewModel.bio)
                .font(.creatoDisplayBody())
                .padding(.horizontal)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                // Navigate to welcome screen
                navigationPath.append(OnboardingStep.welcome)
            }) {
                Text("Next")
                    .font(.creatoDisplayHeadline())
                    .foregroundColor(.whiteui)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.glassProminent)
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $viewModel.selectedImage)
        }
        .onAppear {
            // Preload welcome images when user reaches profile setup
            // This ensures they're ready by the time they reach welcome screen
            Task {
                // Ensure images are fetched first
                if welcomeImageService.images.isEmpty {
                    await welcomeImageService.fetchImages()
                }
                // Preload images into cache
                await welcomeImageService.preloadImages()
            }
        }
        }
    }
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(0.3), location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Image Processing
    
    private func processImage(_ image: UIImage) {
        // Cancel any existing task
        imageProcessingTask?.cancel()
        
        // Optimize image for display on background thread
        imageProcessingTask = Task.detached(priority: .userInitiated) {
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Resize image to reasonable size for display (120x120 @ 2x = 240x240)
            let maxDimension: CGFloat = 240
            let size = image.size
            let maxSize = max(size.width, size.height)
            
            let optimizedImage: UIImage
            if maxSize > maxDimension {
                let scale = maxDimension / maxSize
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                optimizedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                optimizedImage = image
            }
            
            // Check again if task was cancelled after processing
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                displayImage = optimizedImage
            }
        }
    }
}

struct EmailVerificationPage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Binding var navigationPath: NavigationPath
    @State private var checkTimer: Timer?
    @State private var resendTimer: Timer?
    @State private var resendCooldown: Int = 0
    
    var body: some View {
        ZStack {
            // Grid lines background
            gridLinesBackground()
            
            // Content
        VStack(spacing: 20) {
            // Step counter
            StepCounterView(currentStep: 1, totalSteps: 3)
            
            Spacer()
            
            Image(systemName: "envelope.badge")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("Verify Your Email")
                .font(.creatoDisplayTitle())
                .multilineTextAlignment(.center)
            
            Text("We've sent a verification email to your inbox. Please check your email and click the verification link.")
                .font(.creatoDisplayBody())
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if viewModel.isEmailVerificationSent {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Verification email sent!")
                            .font(.creatoDisplayBody(.medium))
                            .foregroundColor(.green)
                    }
                    
                    if !viewModel.isEmailVerified {
                        Text("Waiting for verification...")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            if viewModel.isEmailVerified {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Email verified!")
                            .font(.creatoDisplayBody(.medium))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Resend button - only shown within 60 seconds of last send
            if viewModel.isEmailVerificationSent && !viewModel.isEmailVerified && viewModel.shouldShowResendButton {
                Button(action: {
                    Task {
                        await viewModel.sendVerificationEmail()
                        resendCooldown = 60
                        startResendTimer()
                    }
                }) {
                    HStack {
                        if viewModel.isSendingVerificationEmail {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        if resendCooldown > 0 {
                            Text("Resend in \(resendCooldown)s")
                                .font(.creatoDisplayHeadline())
                                .foregroundColor(.whiteui)
                        } else {
                            Text("Resend Verification Email")
                                .font(.creatoDisplayHeadline())
                                .foregroundColor(.whiteui)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isSendingVerificationEmail || resendCooldown > 0)
            }
        }
        .padding()
        }
        .onAppear {
            // Auto-send verification email when page appears
            Task {
                // Check if email is already verified first
                await viewModel.checkEmailVerificationStatus()

                // If not verified and not sent, send automatically
                if !viewModel.isEmailVerified && !viewModel.isEmailVerificationSent {
                    await viewModel.sendVerificationEmail()
                    resendCooldown = 60
                    startResendTimer()
                } else if viewModel.isEmailVerificationSent && viewModel.shouldShowResendButton {
                    // If email was sent recently, start the resend timer
                    resendCooldown = viewModel.resendCooldownSeconds
                    startResendTimer()
                }
            }
            
            // Start periodic checking if email was sent
            if viewModel.isEmailVerificationSent && !viewModel.isEmailVerified {
                startPeriodicCheck()
            }
        }
        .onDisappear {
            stopPeriodicCheck()
            stopResendTimer()
        }
    }
    
    private func startPeriodicCheck() {
        stopPeriodicCheck() // Clear any existing timer
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task {
                await viewModel.checkEmailVerificationStatus()
            }
        }
    }
    
    private func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func startResendTimer() {
        stopResendTimer() // Clear any existing timer
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let newCooldown = viewModel.resendCooldownSeconds
            if newCooldown != resendCooldown {
                resendCooldown = newCooldown
            }
            // Stop timer when cooldown expires (button should be hidden)
            if resendCooldown <= 0 || !viewModel.shouldShowResendButton {
                stopResendTimer()
            }
        }
    }
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(0.3), location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
    
    private func stopResendTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
    }
}

struct WelcomePage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Binding var navigationPath: NavigationPath
    let welcomeImages: [WelcomeImage]
    @Environment(\.dismiss) private var dismiss
    
    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.5
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var wasLoading: Bool = false
    @State private var hasTriggeredHaptic: Bool = false
    @State private var isReady: Bool = false
    
    var body: some View {
        ZStack {
            // Animated background - fades in first (only show when ready to avoid hitch)
            // Delay creation until ready to prevent hitch during navigation
            if isReady {
                AnimatedMasonryBackground(images: welcomeImages)
                    .opacity(backgroundOpacity)
            } else {
                // Empty placeholder to prevent layout shift
                Color.clear
            }
            
            // Content overlay
            VStack(spacing: 30) {
                Spacer()
                
                // Logo - fades and grows in second
                Image("oravectorcropped")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                
                // Subtext - fades in third
                Text("Curate your aesthetic.")
                    .font(.creatoDisplayBody())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .opacity(textOpacity)
                
                Spacer()
                
                // Button - fades in last
                if viewModel.isLoading {
                    ProgressView("Setting up profile...")
                        .opacity(buttonOpacity)
            } else {
                Button(action: {
                    Task {
                        await viewModel.completeOnboarding()
                        // Dismiss the onboarding view after completion
                        // The app will automatically show ContentView based on isOnboardingCompleted
                        dismiss()
                    }
                }) {
                    Text("Get Started")
                        .font(.creatoDisplayHeadline())
                        .foregroundColor(.whiteui)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
                .buttonStyle(.glassProminent)
                    .opacity(buttonOpacity)
                }
            }
            .padding()
        }
        .onAppear {
            // Prepare the view state first to avoid hitch
            prepareView()
            
            // Small delay to let navigation transition complete, then start animations
            Task { @MainActor in
                // Wait one frame to ensure smooth transition completes
                try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps
                
                // Mark as ready so background can render (but stay invisible)
                isReady = true
                
                // Half second delay before starting animations for a deliberate, polished feel
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                startSequentialAnimations()
            }
            
            wasLoading = viewModel.isLoading
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            // When loading completes (profile setup finished), trigger haptic feedback once
            if wasLoading && !isLoading && !hasTriggeredHaptic {
                triggerHapticFeedback()
                hasTriggeredHaptic = true
            }
            wasLoading = isLoading
        }
    }
    
    private func prepareView() {
        // Pre-initialize states to prevent flash
        backgroundOpacity = 0
        logoOpacity = 0
        logoScale = 0.5
        textOpacity = 0
        buttonOpacity = 0
    }
    
    private func startSequentialAnimations() {
        // 1. Background fades in (0.0s - 0.5s)
        withAnimation(.easeInOut(duration: 0.5)) {
            backgroundOpacity = 1.0
        }
        
        // 2. Logo fades and grows in (0.5s - 1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
        }
        
        // 3. Subtext fades in (1.0s - 1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                textOpacity = 1.0
            }
        }
        
        // 4. Button fades in (1.5s - 2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// Helper ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Requirement Row Component
struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .secondary)
                .font(.caption)
            
            Text(text)
                .font(.creatoDisplayCaption())
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    OnboardingView()
        .previewAuthenticated()
}
