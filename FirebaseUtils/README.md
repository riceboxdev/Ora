# FirebaseUtils

Utility helpers for Firebase development, including emulator configuration.

## Features

- **Emulator Support**: Easy configuration for local Firebase Functions emulator
- **Environment-Based**: Automatically detects debug vs production builds
- **Simple API**: Clean interface for getting configured Functions instances

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../FirebaseUtils")
]
```

Or add it as a local package in Xcode:
1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to the FirebaseUtils directory

**Note**: This package requires Firebase Functions to be added separately to your project.

## Usage

### Basic Usage

```swift
import FirebaseUtils
import FirebaseFunctions

// Get a configured Functions instance
let functions = FunctionsConfig.functions(region: "us-central1")

// Use it to call functions
let function = functions.httpsCallable("myFunction")
let result = try await function.call(["key": "value"])
```

### Local Emulator (Debug Mode)

To use the local emulator in debug builds:

1. Set environment variable `USE_LOCAL_FUNCTIONS=true` in your Xcode scheme
2. Or set it in your environment before running

The package will automatically detect this and connect to `localhost:5001`.

### Production

In release builds, the package always uses cloud functions (emulator is disabled).

## Configuration

The package automatically handles:
- **Debug builds**: Checks for `USE_LOCAL_FUNCTIONS` environment variable
- **Release builds**: Always uses cloud functions

## Architecture

The package consists of:

- **`FunctionsConfig`**: Helper class for configuring Firebase Functions instances

## Migration from Local Implementation

If you're migrating from a local implementation:

1. Add the package to your project
2. Import `FirebaseUtils` where needed
3. Replace local `FunctionsConfig` with `FirebaseUtils.FunctionsConfig`
4. The API remains the same, so no code changes required



