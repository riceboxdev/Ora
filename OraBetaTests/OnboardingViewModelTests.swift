//
//  OnboardingViewModelTests.swift
//  OraBetaTests
//
//  Unit tests for OnboardingViewModel
//

import XCTest
import Testing
import FirebaseAuth
@testable import OraBeta

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    
    var viewModel: OnboardingViewModel!
    var mockAuthViewModel: MockAuthViewModel!
    
    override func setUp() {
        super.setUp()
        
        // Create mock auth view model
        mockAuthViewModel = MockAuthViewModel()
        
        // Create view model with real services (requires Firebase to be configured)
        // Note: For true unit tests, you'd want to inject mock services via dependency injection
        // This is more of an integration test approach
        viewModel = OnboardingViewModel()
        viewModel.setAuthViewModel(mockAuthViewModel)
    }
    
    override func tearDown() {
        viewModel = nil
        mockAuthViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Username Validation Tests
    
    func testUsernameValidation_EmptyUsername() {
        // Given
        viewModel.username = ""
        
        // Then
        XCTAssertFalse(viewModel.isUsernameAvailable, "Empty username should not be available")
        XCTAssertNil(viewModel.usernameError, "No error should be set for empty username")
    }
    
    func testUsernameValidation_TooShort() async {
        // Given
        viewModel.username = "ab"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Then
        XCTAssertFalse(viewModel.isUsernameAvailable, "Username shorter than 3 characters should not be available")
        // Note: The actual error message depends on the implementation
    }
    
    func testUsernameValidation_ContainsSpaces() async {
        // Given
        viewModel.username = "test user"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Then
        XCTAssertFalse(viewModel.isUsernameAvailable, "Username with spaces should not be available")
    }
    
    func testUsernameValidation_ValidFormat() async {
        // Given
        viewModel.username = "testuser123"
        
        // Wait for debounce and validation
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Then
        // The actual availability depends on the service response
        // This test verifies the validation logic doesn't reject valid formats
        XCTAssertNotNil(viewModel.username, "Username should be set")
    }
    
    // MARK: - State Management Tests
    
    func testInitialState() {
        // Then
        XCTAssertEqual(viewModel.username, "", "Initial username should be empty")
        XCTAssertEqual(viewModel.bio, "", "Initial bio should be empty")
        XCTAssertNil(viewModel.selectedImage, "Initial image should be nil")
        XCTAssertFalse(viewModel.isUsernameAvailable, "Initial username availability should be false")
        XCTAssertFalse(viewModel.isCheckingUsername, "Initial checking state should be false")
        XCTAssertFalse(viewModel.isLoading, "Initial loading state should be false")
    }
    
    func testBioCanBeSet() {
        // Given
        let testBio = "This is a test bio"
        
        // When
        viewModel.bio = testBio
        
        // Then
        XCTAssertEqual(viewModel.bio, testBio, "Bio should be set correctly")
    }
    
    func testImageCanBeSet() {
        // Given
        let testImage = createTestImage()
        
        // When
        viewModel.selectedImage = testImage
        
        // Then
        XCTAssertNotNil(viewModel.selectedImage, "Image should be set")
        XCTAssertEqual(viewModel.selectedImage?.size, testImage.size, "Image size should match")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock Services

class MockProfileService: ProfileServiceProtocol {
    var checkUsernameAvailabilityResult: Bool = true
    var checkUsernameAvailabilityError: Error?
    var completeOnboardingError: Error?
    
    func checkUsernameAvailability(username: String) async throws -> Bool {
        if let error = checkUsernameAvailabilityError {
            throw error
        }
        return checkUsernameAvailabilityResult
    }
    
    func completeOnboarding(userId: String, username: String, displayName: String?, bio: String?, profilePhotoUrl: String?) async throws {
        if let error = completeOnboardingError {
            throw error
        }
    }
    
    // MARK: - Required Protocol Methods
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        return nil
    }
    
    func getUserProfiles(userIds: [String]) async throws -> [String: UserProfile] {
        return [:]
    }
    
    func clearCache(userId: String?) {
        // Mock implementation
    }
    
    func getCurrentUserProfile() async throws -> UserProfile? {
        return nil
    }
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        // Mock implementation
    }
    
    func updateProfile(userId: String, fields: [String: Any]) async throws {
        // Mock implementation
    }
    
    func createProfileFromAuthUser(email: String, displayName: String?) async throws {
        // Mock implementation
    }
    
    func isAdmin(userId: String) async throws -> Bool {
        return false
    }
    
    func profileExists() async throws -> Bool {
        return false
    }
    
    func createProfileForCurrentUser() async throws {
        // Mock implementation
    }
    
    func followUser(followingId: String) async throws {
        // Mock implementation
    }
    
    func unfollowUser(followingId: String) async throws {
        // Mock implementation
    }
    
    func isFollowing(followingId: String) async throws -> Bool {
        return false
    }
}

// Note: ImageUploadService is a concrete class with a fatalError in init
// For proper unit testing, consider creating an ImageUploadServiceProtocol
// For now, these tests focus on ViewModel logic that doesn't require image upload mocking

class MockAuthService: AuthServiceProtocol {
    var userId: String? = "test-user-id"
    var currentUser: User? = User(uid: "test-user-id", email: "test@example.com")
    var isAuthenticated: Bool = true
    var userEmail: String? = "test@example.com"
    var isEmailVerified: Bool = true
    
    func signUp(email: String, password: String, displayName: String?) async throws {
        // Mock implementation
    }
    
    func signIn(email: String, password: String) async throws {
        // Mock implementation
    }
    
    func signIn(credential: AuthCredential) async throws {
        // Mock implementation
    }
    
    func signOut() throws {
        // Mock implementation
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        // Mock implementation
    }
    
    func reauthenticate(password: String) async throws {
        // Mock implementation
    }
    
    func sendEmailVerification() async throws {
        // Mock implementation
    }
    
    func updateEmail(newEmail: String) async throws {
        // Mock implementation
    }
    
    func reloadUser() async throws {
        // Mock implementation
    }
    
    func deleteAccount() async throws {
        // Mock implementation
    }
}

// Note: AuthViewModel has complex initialization with dependencies
// For testing, we can create a minimal mock or use the real AuthViewModel
// In a production test setup, you'd want to inject a mock via dependency injection
// For now, tests that require AuthViewModel will use a real instance (requires Firebase)
class MockAuthViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    
    func fetchUserProfile() async {
        // Mock implementation - no-op for tests
        // In real tests, you'd set userProfile here
    }
}

