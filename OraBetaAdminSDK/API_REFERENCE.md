# OraBeta Admin SDK API Reference

Complete API reference for the OraBeta Admin SDK.

## Table of Contents

- [Authentication](#authentication)
- [User Management](#user-management)
- [Post Management](#post-management)
- [Analytics](#analytics)
- [Moderation](#moderation)
- [Post Reporting](#post-reporting)
- [Settings](#settings)
- [Notifications](#notifications)
- [Error Handling](#error-handling)

## Authentication

### `login(firebaseToken:)`

Login with Firebase authentication token.

```swift
let loginResponse = try await client.login(firebaseToken: firebaseToken)
// Token is automatically stored in the client
```

**Parameters:**
- `firebaseToken: String` - Firebase ID token from Firebase Auth

**Returns:** `AdminLoginResponse` containing JWT token and admin info

**Throws:** `AdminError` if login fails

---

### `getCurrentAdmin()`

Get current admin user information.

```swift
let admin = try await client.getCurrentAdmin()
print("Logged in as: \(admin.email)")
```

**Returns:** `AdminUser` with admin information

**Throws:** `AdminError` if the request fails

---

### `refreshToken()`

Refresh the authentication token.

```swift
try await client.refreshToken()
```

**Throws:** `AdminError` if refresh fails

**Note:** This is automatically called when a 401 error is encountered.

## User Management

### `getUsers(limit:offset:)`

Get paginated list of users.

```swift
let users = try await client.getUsers(limit: 50, offset: 0)
print("Total users: \(users.total ?? 0)")
```

**Parameters:**
- `limit: Int` - Maximum number of users (default: 50)
- `offset: Int` - Number of users to skip (default: 0)

**Returns:** `UsersResponse` with list of users

**Throws:** `AdminError` if the request fails

---

### `getUserDetails(userId:)`

Get detailed user information including stats and warnings.

```swift
let userDetails = try await client.getUserDetails(userId: "user123")
print("Post count: \(userDetails.user.stats.postCount)")
```

**Parameters:**
- `userId: String` - The user ID

**Returns:** `UserDetailsResponse` with full user details

**Throws:** `AdminError` if the request fails

---

### `getUserActivity(userId:limit:offset:activityType:startDate:endDate:)`

Get user activity log.

```swift
let activity = try await client.getUserActivity(
    userId: "user123",
    limit: 50,
    activityType: "post"
)
```

**Parameters:**
- `userId: String` - The user ID
- `limit: Int` - Maximum activities (default: 50)
- `offset: Int` - Skip count (default: 0)
- `activityType: String?` - Filter by type ("post", "comment", or nil)
- `startDate: Int64?` - Start timestamp in milliseconds
- `endDate: Int64?` - End timestamp in milliseconds

**Returns:** `UserActivityResponse` with activity entries

**Throws:** `AdminError` if the request fails

---

### `getUserPosts(userId:limit:offset:status:startDate:endDate:)`

Get user's posts.

```swift
let posts = try await client.getUserPosts(
    userId: "user123",
    status: "approved"
)
```

**Parameters:**
- `userId: String` - The user ID
- `limit: Int` - Maximum posts (default: 50)
- `offset: Int` - Skip count (default: 0)
- `status: String?` - Filter by moderation status
- `startDate: Int64?` - Start timestamp
- `endDate: Int64?` - End timestamp

**Returns:** `PostsResponse` with user's posts

**Throws:** `AdminError` if the request fails

---

### `banUser(userId:)`

Ban a user.

```swift
try await client.banUser(userId: "user123")
```

**Parameters:**
- `userId: String` - The user ID to ban

**Throws:** `AdminError` if the request fails

---

### `unbanUser(userId:)`

Unban a user.

```swift
try await client.unbanUser(userId: "user123")
```

**Parameters:**
- `userId: String` - The user ID to unban

**Throws:** `AdminError` if the request fails

---

### `warnUser(userId:warningType:reason:notes:)`

Warn a user.

```swift
try await client.warnUser(
    userId: "user123",
    warningType: "spam",
    reason: "Posting spam content",
    notes: "First warning"
)
```

**Parameters:**
- `userId: String` - The user ID
- `warningType: String` - Type ("spam", "harassment", "inappropriate_content", "terms_violation", "other")
- `reason: String` - Reason for warning
- `notes: String?` - Optional additional notes

**Throws:** `AdminError` if the request fails

---

### `tempBanUser(userId:duration:reason:notes:)`

Temporarily ban a user.

```swift
try await client.tempBanUser(
    userId: "user123",
    duration: 24, // hours
    reason: "Violation of terms"
)
```

**Parameters:**
- `userId: String` - The user ID
- `duration: Int` - Duration in hours
- `reason: String` - Reason for ban
- `notes: String?` - Optional notes

**Throws:** `AdminError` if the request fails

---

### `updateUserRole(userId:role:)`

Update user role.

```swift
try await client.updateUserRole(userId: "user123", role: "moderator")
```

**Parameters:**
- `userId: String` - The user ID
- `role: String` - New role ("admin", "moderator", "user")

**Throws:** `AdminError` if the request fails

---

### `deleteUser(userId:)`

Delete a user.

```swift
try await client.deleteUser(userId: "user123")
```

**Parameters:**
- `userId: String` - The user ID to delete

**Throws:** `AdminError` if the request fails

## Post Management

### `getPosts(limit:offset:filters:)`

Get posts with filters.

```swift
let filters = PostFilters(status: "pending", userId: "user123")
let posts = try await client.getPosts(limit: 50, filters: filters)
```

**Parameters:**
- `limit: Int` - Maximum posts (default: 50)
- `offset: Int` - Skip count (default: 0)
- `filters: PostFilters?` - Optional filters

**Returns:** `PostsResponse` with posts

**Throws:** `AdminError` if the request fails

---

### `getPostDetails(postId:)`

Get detailed post information.

```swift
let post = try await client.getPostDetails(postId: "post123")
```

**Parameters:**
- `postId: String` - The post ID

**Returns:** `PostDetails` with full post information

**Throws:** `AdminError` if the request fails

---

### `updatePost(postId:updates:)`

Update a post.

```swift
let updates = PostUpdate(
    caption: "Updated caption",
    moderationStatus: "approved"
)
try await client.updatePost(postId: "post123", updates: updates)
```

**Parameters:**
- `postId: String` - The post ID
- `updates: PostUpdate` - Fields to update

**Throws:** `AdminError` if the request fails

---

### `deletePost(postId:)`

Delete a post.

```swift
try await client.deletePost(postId: "post123")
```

**Parameters:**
- `postId: String` - The post ID to delete

**Throws:** `AdminError` if the request fails

---

### `bulkPostAction(postIds:action:moderationReason:)`

Perform bulk action on posts.

```swift
try await client.bulkPostAction(
    postIds: ["post1", "post2"],
    action: .approve
)
```

**Parameters:**
- `postIds: [String]` - Array of post IDs
- `action: BulkPostAction` - Action (.approve, .reject, .flag, .delete)
- `moderationReason: String?` - Optional reason

**Throws:** `AdminError` if the request fails

## Analytics

### `getAnalytics(period:)`

Get analytics data.

```swift
let analytics = try await client.getAnalytics(period: "30d")
print("Total users: \(analytics.users.total)")
```

**Parameters:**
- `period: String` - Time period ("7d", "30d", "90d", "all", default: "30d")

**Returns:** `AnalyticsResponse` with analytics data

**Throws:** `AdminError` if the request fails

## Moderation

### `getModerationQueue(status:)`

Get moderation queue.

```swift
let queue = try await client.getModerationQueue(status: "pending")
```

**Parameters:**
- `status: String?` - Filter by status ("pending", "flagged", or nil for all)

**Returns:** `ModerationQueueResponse` with posts

**Throws:** `AdminError` if the request fails

---

### `approvePost(postId:)`

Approve a post.

```swift
try await client.approvePost(postId: "post123")
```

**Parameters:**
- `postId: String` - The post ID to approve

**Throws:** `AdminError` if the request fails

---

### `rejectPost(postId:)`

Reject a post.

```swift
try await client.rejectPost(postId: "post123")
```

**Parameters:**
- `postId: String` - The post ID to reject

**Throws:** `AdminError` if the request fails

---

### `flagPost(postId:)`

Flag a post.

```swift
try await client.flagPost(postId: "post123")
```

**Parameters:**
- `postId: String` - The post ID to flag

**Throws:** `AdminError` if the request fails

## Post Reporting

### `reportPost(postId:reason:description:firebaseToken:)`

Report a post (public endpoint).

```swift
try await client.reportPost(
    postId: "post123",
    reason: "spam",
    description: "This is spam",
    firebaseToken: firebaseToken
)
```

**Parameters:**
- `postId: String` - The post ID
- `reason: String` - Reason ("spam", "inappropriate", "harassment", "other")
- `description: String?` - Optional description
- `firebaseToken: String` - Firebase ID token (not admin token)

**Throws:** `AdminError` if the request fails

---

### `getMyReports(firebaseToken:)`

Get all reports made by current user.

```swift
let reports = try await client.getMyReports(firebaseToken: firebaseToken)
```

**Parameters:**
- `firebaseToken: String` - Firebase ID token

**Returns:** `UserReportsResponse` with user's reports

**Throws:** `AdminError` if the request fails

## Settings

### `getSystemSettings()`

Get system settings.

```swift
let settings = try await client.getSystemSettings()
print("Maintenance mode: \(settings.settings.maintenanceMode ?? false)")
```

**Returns:** `SystemSettingsResponse` with settings

**Throws:** `AdminError` if the request fails

---

### `updateSystemSettings(settings:)`

Update system settings.

```swift
let update = SystemSettingsUpdate(
    featureFlags: ["newFeature": true],
    maintenanceMode: false
)
try await client.updateSystemSettings(settings: update)
```

**Parameters:**
- `settings: SystemSettingsUpdate` - Settings to update

**Throws:** `AdminError` if the request fails

## Notifications

### `createNotification(notification:)`

Create a notification.

```swift
let notification = NotificationCreate(
    title: "New Feature",
    body: "Check out our new feature!",
    type: "push"
)
let created = try await client.createNotification(notification: notification)
```

**Parameters:**
- `notification: NotificationCreate` - Notification details

**Returns:** `NotificationResponse` with created notification

**Throws:** `AdminError` if the request fails

---

### `getNotifications(status:)`

Get notifications.

```swift
let notifications = try await client.getNotifications(status: "draft")
```

**Parameters:**
- `status: String?` - Filter by status ("draft", "scheduled", "sending", "sent", "failed", or nil)

**Returns:** `NotificationsResponse` with notifications

**Throws:** `AdminError` if the request fails

---

### `getNotificationDetails(notificationId:)`

Get notification details.

```swift
let notification = try await client.getNotificationDetails(notificationId: "notif123")
```

**Parameters:**
- `notificationId: String` - The notification ID

**Returns:** `NotificationResponse` with notification details

**Throws:** `AdminError` if the request fails

---

### `sendNotification(notificationId:)`

Send a notification.

```swift
try await client.sendNotification(notificationId: "notif123")
```

**Parameters:**
- `notificationId: String` - The notification ID to send

**Throws:** `AdminError` if the request fails

## Error Handling

The SDK uses `AdminError` enum for all errors. Handle errors appropriately:

```swift
do {
    let users = try await client.getUsers()
} catch AdminError.unauthorized {
    // Handle unauthorized - re-login
} catch AdminError.forbidden {
    // Handle insufficient permissions
} catch AdminError.networkError(let error) {
    // Handle network issues
} catch AdminError.serverError(let message) {
    // Handle server errors
} catch {
    // Handle other errors
}
```

### Error Types

- `invalidConfiguration` - Invalid SDK configuration
- `invalidInput(String)` - Invalid input parameters
- `networkError(Error)` - Network connectivity issues
- `serverError(String)` - Server-side errors
- `unauthorized` - Authentication required
- `forbidden` - Insufficient permissions
- `notFound` - Resource not found
- `rateLimited(retryAfter: Int?)` - Rate limit exceeded
- `validationError(field: String, message: String)` - Input validation failed
- `conflict(String)` - Resource conflict
- `timeout` - Request timeout
- `badRequest(String)` - Invalid request
- `unknown` - Unknown error

## Caching

The SDK includes automatic caching for frequently accessed data:

- Analytics: 5 minutes TTL
- Users list: 2 minutes TTL
- Moderation queue: 1 minute TTL
- Posts list: 2 minutes TTL
- Settings: 10 minutes TTL

Cache is automatically invalidated on write operations. You can manually clear cache:

```swift
client.clearCache()
```

Disable caching:

```swift
let config = AdminConfig(cacheEnabled: false)
let client = AdminClient(config: config)
```

## Retry Logic

The SDK automatically retries failed requests:

- Network errors: Up to 3 retries with exponential backoff
- Server errors (5xx): Up to 2 retries
- Client errors (4xx): No retries (except 408 timeout)
- Automatic token refresh on 401 errors

Configure retry behavior:

```swift
let client = AdminClient(
    config: config,
    maxRetries: 5,
    retryDelay: 2.0
)
```

