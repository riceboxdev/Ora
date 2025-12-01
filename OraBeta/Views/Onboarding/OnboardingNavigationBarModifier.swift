import SwiftUI

/// A view modifier that adds a sign-out button to the navigation bar
/// and applies consistent styling to onboarding screens
struct OnboardingNavigationBarModifier: ViewModifier {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Whether to show the sign-out button (default is true)
    var showSignOut: Bool
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showSignOut {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                await authViewModel.signOut()
                                dismiss()
                            }
                        }) {
                            Text("Sign Out")
                                .font(.creatoDisplayBody())
                                .foregroundColor(.red)
                        }
                    }
                }
            }
    }
}

extension View {
    /// Applies standard onboarding navigation bar styling with an optional sign-out button
    /// - Parameter showSignOut: Whether to show the sign-out button (default is true)
    func onboardingNavigationBar(showSignOut: Bool = true) -> some View {
        self.modifier(OnboardingNavigationBarModifier(showSignOut: showSignOut))
    }
}
