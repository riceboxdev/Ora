# OraLogging

A centralized logging system for Swift with configurable log levels and service-level logging control.

## Features

- **Configurable Log Levels**: Support for `none`, `minimal`, and `full` logging modes
- **Service-Level Control**: Enable/disable logging per service with a registry pattern
- **Thread-Safe**: All operations are thread-safe using locks
- **Persistent State**: Service enabled/disabled states are saved to UserDefaults
- **Simple API**: Easy-to-use static methods for logging

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../OraLogging")
]
```

Or add it as a local package in Xcode:
1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to the OraLogging directory

## Usage

### Basic Setup

Configure the logging system early in your app initialization:

```swift
import OraLogging

// In your AppDelegate or App init
let configuration = LoggingConfiguration(
    defaultLogLevel: .full,  // or .minimal, .none
    serviceLogLevels: [
        "NetworkService": .full,
        "CacheService": .minimal
    ],
    serviceLoggingStates: [
        "DebugService": false  // Disable specific service
    ]
)
LoggingConfig.configure(configuration)
```

### Logging Messages

```swift
import OraLogging

// Info messages (only in full mode)
Logger.info("User logged in", service: "AuthService")

// Debug messages (only in full mode)
Logger.debug("Cache hit for key: \(key)", service: "CacheService")

// Warning messages (logged in minimal and full mode)
Logger.warning("API rate limit approaching", service: "NetworkService")

// Error messages (always logged)
Logger.error("Failed to save data", service: "DatabaseService")
```

### Controlling Logging

```swift
import OraLogging

// Enable/disable specific services
LoggingControl.enable("NetworkService")
LoggingControl.disable("CacheService")

// Toggle a service
LoggingControl.toggle("DebugService")

// Check if a service is enabled
if LoggingControl.isEnabled("NetworkService") {
    // ...
}

// Get all registered services
let services = LoggingControl.allServices()

// Print current logging state (useful for debugging)
LoggingControl.printState()
```

## Log Levels

- **`.none`**: No logging
- **`.minimal`**: Only errors and warnings
- **`.full`**: All messages including info and debug

## Architecture

The package consists of:

- **`Logger`**: Main logging interface with static methods
- **`LogLevel`**: Enumeration of log levels
- **`LoggingConfig`**: Configuration management
- **`LoggingServiceRegistry`**: Service registry for enabling/disabling services
- **`LoggingControl`**: Convenience helpers for controlling logging
- **`LoggingConfiguration`**: Configuration struct

## Thread Safety

All operations are thread-safe. The `LoggingServiceRegistry` uses `NSLock` to ensure safe concurrent access.

## Migration from Local Implementation

If you're migrating from a local logging implementation:

1. Add the package to your project
2. Import `OraLogging` where needed
3. Configure the package early in app initialization using `LoggingConfig.configure()`
4. Replace local logging imports with `import OraLogging`

The API is designed to be compatible with common logging patterns, so minimal code changes should be required.






