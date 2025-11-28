# Onboarding Flow Testing Guide

This document describes the testing and preview system for the onboarding flow.

## 📋 Overview

The onboarding testing system provides multiple ways to preview and test the onboarding experience:

1. **SwiftUI Previews** - Visual testing in Xcode
2. **OnboardingPreview** - Interactive state selector for testing different scenarios
3. **Unit Tests** - Automated testing of ViewModel logic
4. **Manual Testing** - Step-by-step testing checklist

## 🎨 SwiftUI Previews

### Basic Previews

The `OnboardingView.swift` file includes multiple preview scenarios:

```swift
#Preview("Onboarding - Full Flow")
#Preview("Username Page")
#Preview("Profile Setup Page")
#Preview("Welcome Page")
```

**How to use:**
1. Open `OnboardingView.swift` in Xcode
2. Click the preview button (⌥⌘↩) or use the canvas
3. Select different preview scenarios from the preview picker

### Preview with Authentication

The previews use `.previewAuthenticated()` which automatically:
- Creates/signs in a test Firebase user
- Sets up the AuthViewModel
- Provides a fully functional preview environment

## 🎛️ OnboardingPreview - Interactive Testing

The `OnboardingPreview.swift` file provides an interactive preview system that lets you test different states of the onboarding flow.

### Features

- **State Selector**: Choose from 13 different preview states
- **Step Selector**: Navigate between Username, Profile Setup, and Welcome pages
- **Mock ViewModel**: Uses a mock ViewModel that doesn't require Firebase

### Available Preview States

#### Username Page States
- `usernameEmpty` - Empty username field
- `usernameTyping` - User is typing (3+ characters)
- `usernameChecking` - Checking availability (loading state)
- `usernameAvailable` - Username is available
- `usernameTaken` - Username is already taken
- `usernameInvalid` - Username doesn't meet requirements

#### Profile Setup States
- `profileSetupEmpty` - No image or bio
- `profileSetupWithImage` - Profile image selected
- `profileSetupWithBio` - Bio entered
- `profileSetupComplete` - Both image and bio

#### Welcome Page States
- `welcomeReady` - Ready to complete onboarding
- `welcomeLoading` - Completing onboarding (loading)
- `welcomeError` - Error occurred during completion

### How to Use

1. Open `OnboardingPreview.swift` in Xcode
2. Run the preview (⌥⌘↩)
3. Use the dropdown to select different states
4. Use the segmented control to switch between steps
5. Observe how the UI responds to different states

### Preview Scenarios

```swift
#Preview("Onboarding Preview - Full Flow")
#Preview("Username Page - Empty")
#Preview("Username Page - Available")
#Preview("Profile Setup - Complete")
#Preview("Welcome Page - Ready")
```

## 🧪 Unit Tests

### Test File Location

`OraBetaTests/OnboardingViewModelTests.swift`

### Test Coverage

#### Username Validation Tests
- ✅ Empty username validation
- ✅ Too short username (< 3 characters)
- ✅ Username with spaces
- ✅ Valid username format

#### State Management Tests
- ✅ Initial state verification
- ✅ Bio can be set
- ✅ Image can be set

### Running Tests

**In Xcode:**
1. Press `⌘U` to run all tests
2. Or click the diamond icon next to individual test methods

**Command Line:**
```bash
xcodebuild test -scheme OraBeta -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Limitations

Currently, the tests use real services (require Firebase configuration). For true unit testing:

1. **Create Service Protocols** (if not already exists):
   - `ImageUploadServiceProtocol`
   - Ensure `ProfileServiceProtocol` and `AuthServiceProtocol` are used

2. **Inject Mock Services**:
   ```swift
   let container = DIContainer()
   container.profileService = MockProfileService()
   container.imageUploadService = MockImageUploadService()
   viewModel = OnboardingViewModel(container: container)
   ```

3. **Mock Implementations**:
   - See `MockProfileService` in the test file for reference
   - Create similar mocks for other services

## 📝 Manual Testing Checklist

### Username Page
- [ ] Empty username shows requirements as unmet
- [ ] Typing a username triggers validation
- [ ] Username < 3 characters shows error
- [ ] Username with spaces shows error
- [ ] Valid username shows checking state
- [ ] Available username shows success indicator
- [ ] Taken username shows error message
- [ ] Next button is disabled until username is available

### Profile Setup Page
- [ ] Image picker opens when tapping profile image
- [ ] Selected image displays correctly
- [ ] Bio field accepts text input
- [ ] Next button is always enabled (optional fields)

### Welcome Page
- [ ] "Get Started" button is visible
- [ ] Tapping button shows loading state
- [ ] Onboarding completes successfully
- [ ] Error handling works correctly

### Full Flow
- [ ] Can navigate through all steps
- [ ] Back navigation is disabled (as designed)
- [ ] Logout button works on username page
- [ ] All data persists between steps
- [ ] Onboarding completion updates profile correctly

## 🔧 Troubleshooting

### Preview Not Showing
- Ensure Firebase is configured in `GoogleService-Info.plist`
- Check that preview authentication completes (watch console)
- Try restarting Xcode previews

### Tests Failing
- Ensure Firebase emulator is running (if using local testing)
- Check that test user credentials are valid
- Verify all required services are initialized

### Mock ViewModel Not Working
- Ensure `MockOnboardingViewModel` implements all required properties
- Check that preview views use the mock correctly
- Verify state updates trigger UI refreshes

## 📚 Related Files

- `OraBeta/Views/Onboarding/OnboardingView.swift` - Main onboarding view
- `OraBeta/Views/Onboarding/OnboardingPreview.swift` - Preview system
- `OraBeta/ViewModels/OnboardingViewModel.swift` - ViewModel logic
- `OraBeta/PreviewHelpers.swift` - Preview authentication helpers
- `OraBetaTests/OnboardingViewModelTests.swift` - Unit tests

## 🚀 Future Improvements

1. **Protocol-Based Services**: Create protocols for all services to enable better mocking
2. **Snapshot Testing**: Add snapshot tests for UI consistency
3. **UI Tests**: Add automated UI tests for the full onboarding flow
4. **Accessibility Testing**: Ensure onboarding is accessible
5. **Localization Testing**: Test with different languages and text lengths






