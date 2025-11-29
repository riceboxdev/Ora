//
//  CustomWaitlistView.swift
//  OraBeta
//
//  Custom waitlist UI styled to match onboarding pages
//

import SwiftUI
#if canImport(Waitlist)
import Waitlist
#endif

/// Custom waitlist view styled to match the onboarding design
struct CustomWaitlistView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let remoteConfigService: RemoteConfigService
    
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @State private var position: Int?
    @State private var hasJoined: Bool = false
    @State private var isAccepted: Bool = false
    @State private var showAcceptedMessage: Bool = false
    
    #if canImport(Waitlist)
    private var waitlistClient: WaitlistClient? {
        let router = AppRouter(
            authViewModel: authViewModel,
            remoteConfigService: remoteConfigService
        )
        guard let config = router.waitlistConfig else { return nil }
        return WaitlistClient(config: config)
    }
    #endif
    
    var body: some View {
        ZStack {
            // Grid lines background (matching onboarding)
            gridLinesBackground()
            
            // Content
            VStack(spacing: 20) {
                Spacer()
                
                // Title
                Text("Join the Waitlist")
                    .font(.creatoDisplayTitle())
                    .padding(.horizontal)
                    .hLeading()
                
                // Subtitle
                Text("Be among the first to experience Ora. We'll notify you when it's your turn.")
                    .font(.creatoDisplayBody())
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .hLeading()
                
                if isAccepted || showAcceptedMessage {
                    // User has been accepted
                    acceptedView
                } else if showSuccess {
                    // Success state
                    successView
                } else if hasJoined {
                    // Already joined state
                    alreadyJoinedView
                } else {
                    // Signup form
                    signupForm
                }
                
                Spacer()
            }
        }
        .onAppear {
            checkIfAlreadyJoined()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToLogin"))) { _ in
            // This will be handled by the routing pipeline
            // The view will update when currentRoute changes
        }
    }
    
    // MARK: - Signup Form
    
    private var signupForm: some View {
        VStack(spacing: 20) {
            // Email input
            TextField("Email", text: $email)
                .font(.creatoDisplayHeadline(.regular))
                .padding(.horizontal)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .padding(.horizontal)
            
            // Error message
            if let error = errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .font(.creatoDisplayCaption())
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .hLeading()
            }
            
            // Join button
            Button(action: {
                Task {
                    await joinWaitlist()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join Waitlist")
                            .font(.creatoDisplayHeadline())
                            .foregroundColor(.whiteui)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
            }
            .buttonStyle(.glassProminent)
            .disabled(isLoading || email.isEmpty || !isValidEmail(email))
            .padding(.horizontal)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 20) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top, 40)
            
            // Success message
            Text("You're on the list!")
                .font(.creatoDisplayTitle())
                .padding(.horizontal)
            
            Text("We'll notify you when it's your turn.")
                .font(.creatoDisplayBody())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Position info
            if let position = position {
                Text("Position: #\(position)")
                    .font(.creatoDisplayHeadline())
                    .foregroundColor(.primary)
                    .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Accepted View
    
    private var acceptedView: some View {
        VStack(spacing: 20) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top, 40)
            
            // Accepted message
            Text("You've been accepted!")
                .font(.creatoDisplayTitle())
                .padding(.horizontal)
            
            Text("Welcome to Ora! You can now create an account and start using the app.")
                .font(.creatoDisplayBody())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Continue to login button
            Button(action: {
                // Navigate to login by triggering route refresh
                // The routing pipeline will see they're not authenticated and route to login
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToLogin"), object: nil)
            }) {
                Text("Continue to Login")
                    .font(.creatoDisplayHeadline())
                    .foregroundColor(.whiteui)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Already Joined View
    
    private var alreadyJoinedView: some View {
        VStack(spacing: 20) {
            // Check icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top, 40)
            
            // Message
            Text("You're already on the waitlist")
                .font(.creatoDisplayTitle())
                .padding(.horizontal)
            
            Text("We'll notify you when it's your turn.")
                .font(.creatoDisplayBody())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Check status button
            Button(action: {
                Task {
                    await checkStatus()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Check Status")
                            .font(.creatoDisplayHeadline())
                            .foregroundColor(.whiteui)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
            }
            .buttonStyle(.glassProminent)
            .disabled(isLoading)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Background
    
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
    
    // MARK: - Actions
    
    #if canImport(Waitlist)
    private func checkIfAlreadyJoined() {
        guard let client = waitlistClient else { return }
        hasJoined = client.hasJoined()
        
        // If already joined, check status
        if hasJoined {
            Task {
                await checkStatus()
            }
        }
    }
    
    private func joinWaitlist() async {
        guard let client = waitlistClient else {
            await MainActor.run {
                errorMessage = "Waitlist configuration is missing"
            }
            return
        }
        
        guard isValidEmail(email) else {
            await MainActor.run {
                errorMessage = "Please enter a valid email address"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await client.signup(email: email)
            await MainActor.run {
                self.position = response.position
                self.showSuccess = true
                self.hasJoined = true
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch let error as WaitlistError {
            await MainActor.run {
                self.isLoading = false
                switch error {
                case .alreadySignedUp:
                    self.errorMessage = "This email is already on the waitlist"
                    self.hasJoined = true
                case .invalidEmail:
                    self.errorMessage = "Please enter a valid email address"
                case .networkError:
                    self.errorMessage = "Network error. Please check your connection."
                case .serverError(let message):
                    self.errorMessage = message
                default:
                    self.errorMessage = "An error occurred. Please try again."
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }
    
    private func checkStatus() async {
        guard let client = waitlistClient else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            if let status = try await client.checkStoredStatus() {
                await MainActor.run {
                    self.position = status.position
                    self.isLoading = false
                    
                    // If user is accepted, show accepted view and store acceptance status
                    if status.accepted {
                        Logger.info("User has been accepted from waitlist!", service: "CustomWaitlistView")
                        self.isAccepted = true
                        self.showAcceptedMessage = true
                        
                        // Store acceptance status in UserDefaults so WaitlistGuard can check it
                        if let client = self.waitlistClient {
                            // Get waitlist ID from the router config
                            let router = AppRouter(
                                authViewModel: self.authViewModel,
                                remoteConfigService: self.remoteConfigService
                            )
                            if let config = router.waitlistConfig {
                                let acceptanceKey = "WaitlistAccepted_\(config.waitlistId)"
                                UserDefaults.standard.set(true, forKey: acceptanceKey)
                                Logger.debug("Stored acceptance status for waitlist: \(config.waitlistId)", service: "CustomWaitlistView")
                                
                                // Trigger route refresh to navigate to login
                                NotificationCenter.default.post(name: NSNotification.Name("NavigateToLogin"), object: nil)
                            }
                        }
                    } else {
                        Logger.debug("User is still waiting on waitlist - position: \(status.position)", service: "CustomWaitlistView")
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    // No stored status found - user might not be on waitlist anymore
                    Logger.debug("No stored waitlist status found", service: "CustomWaitlistView")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Unable to check status. Please try again."
                Logger.error("Error checking waitlist status: \(error.localizedDescription)", service: "CustomWaitlistView")
            }
        }
    }
    #else
    private func checkIfAlreadyJoined() {}
    private func joinWaitlist() async {}
    private func checkStatus() async {}
    #endif
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

