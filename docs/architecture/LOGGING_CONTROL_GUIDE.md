# Logging Control System Guide

## Overview

The logging system now supports service-level control, allowing you to enable/disable logging for individual services from a central location.

## Features

1. **Automatic Service Registration**: Services are automatically registered when they first log a message
2. **Per-Service Toggle**: Enable or disable logging for any service individually
3. **Persistent Settings**: Your preferences are saved and persist across app launches
4. **Centralized Control**: Manage all services from one place

## How to Use

### Option 1: Via Admin Dashboard (Recommended)

1. Open the Admin Dashboard in your app
2. Navigate to the "Developer Tools" section
3. Tap "Logging Control"
4. Toggle services on/off as needed
5. Use the buttons at the bottom:
   - **Enable All**: Enable logging for all services
   - **Disable All**: Disable logging for all services
   - **Reset to Defaults**: Reset all services to their default state from Config.swift

### Option 2: Via Code

Use the convenience functions in `LoggingHelpers.swift`:

```swift
// Enable a service
LoggingControl.enable("StreamService")

// Disable a service
LoggingControl.disable("ImageSegmentationService")

// Toggle a service
LoggingControl.toggle("PostService")

// Check if a service is enabled
if LoggingControl.isEnabled("StreamService") {
    // Do something
}

// Get all registered services
let services = LoggingControl.allServices()

// Enable/disable all
LoggingControl.enableAll()
LoggingControl.disableAll()

// Reset to defaults
LoggingControl.resetToDefaults()

// Print current state (useful for debugging)
LoggingControl.printState()
```

### Option 3: Via Config.swift (Default States)

Set default enabled/disabled states in `Config.swift`:

```swift
static var serviceLoggingStates: [String: Bool] = [
    "StreamService": true,              // Enabled by default
    "ImageSegmentationService": false,  // Disabled by default
    "PostService": true                 // Enabled by default
]
```

Services not in this dictionary default to **enabled**.

## How It Works

1. **Service Registration**: When a service logs a message using `Logger.log()`, it's automatically registered with the logging system
2. **State Check**: Before logging, the system checks:
   - Is the service enabled? (from LoggingServiceRegistry)
   - Does the log level match the current configuration? (from LoggingConfig)
3. **Persistence**: Service states are saved to UserDefaults and persist across app launches

## Log Levels

The existing 3-level system still works:

- **.none**: No logging
- **.minimal**: Errors and warnings only
- **.full**: All logging including debug info

Service enable/disable is checked **before** log level, so:
- If a service is disabled, no logs will appear regardless of log level
- If a service is enabled, logs will appear based on the log level setting

## Example Services

Common services you might want to control:

- `StreamService`
- `ImageSegmentationService`
- `PostService`
- `PostAnalysisService`
- `ImageUploadService`
- `FeedService`
- `ProfileService`
- `NotificationManager`
- `UploadQueueService`

## Tips

1. **Use the Admin Dashboard**: The easiest way to manage logging is through the Admin Dashboard
2. **Search**: Use the search bar in Logging Control to quickly find services
3. **Defaults**: Set default states in Config.swift for services you always want on/off
4. **Debug**: Use `LoggingControl.printState()` to see all current states in the console

## Technical Details

- **Thread-Safe**: The registry uses locks for thread-safe access
- **Automatic**: Services register themselves automatically on first use
- **Persistent**: Settings are saved to UserDefaults with key format: `LoggingService_{serviceName}_enabled`
- **Backwards Compatible**: Existing logging code continues to work without changes






