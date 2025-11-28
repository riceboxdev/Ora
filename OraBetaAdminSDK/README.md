# OraBeta Admin SDK

Swift SDK for interacting with the OraBeta Admin API. Follows the same pattern as the Waitlist SDK.

## Installation

### Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, go to File → Add Package Dependencies
2. Add the package URL (or use local path during development)
3. Import the OraBetaAdmin module in your Swift files

## Usage

### Basic Setup

```swift
import OraBetaAdmin
import FirebaseAuth

// Configure the SDK
let config = AdminConfig(
    baseURL: "https://orabeta-admin.vercel.app"
)

let client = AdminClient(config: config)
```

### Authentication

```swift
// Login with Firebase Auth token
let user = try await Auth.auth().currentUser
let firebaseToken = try await user.getIDToken()

let loginResponse = try await client.login(firebaseToken: firebaseToken)
// Token is automatically stored in the client
print("Logged in as: \(loginResponse.admin.email)")
```

### User Management

```swift
// Get all users
let users = try await client.getUsers(limit: 50, offset: 0)
print("Total users: \(users.total)")

// Ban a user
try await client.banUser(userId: "user123")

// Unban a user
try await client.unbanUser(userId: "user123")
```

### Analytics

```swift
// Get analytics for last 30 days
let analytics = try await client.getAnalytics(period: "30d")
print("Total users: \(analytics.users.total)")
print("Total posts: \(analytics.posts.total)")
print("Total likes: \(analytics.engagement.likes)")
```

### Moderation

```swift
// Get moderation queue
let queue = try await client.getModerationQueue(status: "pending")
print("Pending posts: \(queue.count)")

// Approve a post
try await client.approvePost(postId: "post123")

// Reject a post
try await client.rejectPost(postId: "post456")

// Flag a post
try await client.flagPost(postId: "post789")
```

### System Settings

```swift
// Get system settings
let settings = try await client.getSystemSettings()
print("Maintenance mode: \(settings.settings.maintenanceMode ?? false)")
```

## API Reference

See [API_REFERENCE.md](API_REFERENCE.md) for complete API documentation.

For the standard SDK pattern used, see the SDK_PATTERN.md documentation.






