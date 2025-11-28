# FeatureFlags

A protocol-based feature flag management system for Swift with Firebase Remote Config support.

## Features

- **Protocol-Based**: Abstract interface allows different backends (Firebase, custom API, local config)
- **Firebase Support**: Built-in Firebase Remote Config provider
- **Observable**: Uses Combine for reactive updates
- **Type-Safe**: Centralized access to feature flags
- **JSON Support**: Supports both individual flags and JSON-based flag bundles

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../FeatureFlags")
]
```

Or add it as a local package in Xcode:
1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to the FeatureFlags directory

**Note**: This package requires Firebase Remote Config to be added separately to your project for the Firebase provider to work.

## Usage

### Basic Setup with Firebase

**Note**: The Firebase provider implementation is in the app (not the package) to avoid Firebase dependencies. The package provides the protocol and service only.

```swift
import FeatureFlags
import FirebaseRemoteConfig

// Create Firebase provider with defaults (this is in your app)
let defaults: [String: NSObject] = [
    "showAds": true as NSObject,
    "waitlistEnabled": false as NSObject,
    "maintenanceMode": false as NSObject,
    "featureFlags": "" as NSObject
]

let provider = FirebaseFeatureFlagProvider(defaults: defaults)
let service = FeatureFlagService(provider: provider)

// Initialize after Firebase is configured
service.initialize()
```

For a complete Firebase implementation example, see `OraBeta/Services/FirebaseFeatureFlagProvider.swift` in the app.

### Using Feature Flags

```swift
import FeatureFlags

// Access flags via the service
if FeatureFlagService.shared.areAdsEnabled {
    // Show ads
}

// Or use the global helper
if FeatureFlags.isStoriesEnabled {
    // Show stories feature
}

// Observe changes in SwiftUI
struct MyView: View {
    @ObservedObject var service = FeatureFlagService.shared
    
    var body: some View {
        if service.isWaitlistEnabled {
            WaitlistView()
        }
    }
}
```

### Custom Provider

You can create custom providers for other backends:

```swift
import FeatureFlags

class CustomAPIProvider: FeatureFlagProvider {
    func initialize() {
        // Setup your custom backend
    }
    
    func fetchFlags(completion: @escaping (Bool, Error?) -> Void) {
        // Fetch from your API
        completion(true, nil)
    }
    
    func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        // Return flag value
        return defaultValue
    }
    
    func stringValue(forKey key: String, defaultValue: String) -> String {
        // Return flag value
        return defaultValue
    }
}

// Use it
let provider = CustomAPIProvider()
let service = FeatureFlagService(provider: provider)
```

## Architecture

The package consists of:

- **`FeatureFlagProvider`**: Protocol for flag providers
- **`FeatureFlagService`**: Observable service that manages flags
- **`FeatureFlags`**: Global helper struct for type-safe access

**Note**: Firebase implementation (`FirebaseFeatureFlagProvider`) is provided in the app to avoid Firebase dependencies in the package. You can create your own provider implementations for other backends.

## JSON-Based Flags

The service supports JSON-based flag bundles for managing multiple flags at once:

```json
{
  "storiesEnabled": false,
  "adsEnabled": true,
  "waitlistEnabled": false
}
```

This allows a single Remote Config parameter to control multiple feature flags.

## Thread Safety

The service uses Combine's `@Published` properties and is designed to be used on the main thread. All updates are dispatched to the main queue.

## Migration from Local Implementation

If you're migrating from a local implementation:

1. Add the package to your project
2. Import `FeatureFlags` where needed
3. Replace local `RemoteConfigService` with `FeatureFlagService` using `FirebaseFeatureFlagProvider`
4. The API is similar, so minimal code changes should be required

