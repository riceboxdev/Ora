# Admin System Architecture Analysis

## Overview

This document provides a comprehensive analysis of how the iOS SDK, admin backend, and admin dashboard interact, along with architectural recommendations.

## System Components

### 1. iOS SDK (OraBetaAdminSDK)

**Location**: `/OraBetaAdminSDK/`

**Purpose**: Swift SDK for iOS app to interact with admin backend API

**Current Features**:

#### Authentication
- ✅ `login(firebaseToken:)` - Login with Firebase token, returns JWT token
- ✅ `getCurrentAdmin()` - Get current admin user info

#### User Management
- ✅ `getUsers(limit:offset:)` - Get paginated list of users
- ✅ `banUser(userId:)` - Ban a user
- ✅ `unbanUser(userId:)` - Unban a user

#### Analytics
- ✅ `getAnalytics(period:)` - Get analytics data (7d, 30d, 90d, all)
  - Returns: users (total, new), posts (total, pending, flagged), engagement (likes, comments, shares, saves, views)

#### Moderation
- ✅ `getModerationQueue(status:)` - Get moderation queue (pending, flagged, or all)
- ✅ `approvePost(postId:)` - Approve a post
- ✅ `rejectPost(postId:)` - Reject a post
- ✅ `flagPost(postId:)` - Flag a post

#### Post Reporting (Public Endpoints)
- ✅ `reportPost(postId:reason:description:firebaseToken:)` - Report a post (uses Firebase token, not admin token)
- ✅ `getMyReports(firebaseToken:)` - Get all reports made by current user

#### Settings
- ✅ `getSystemSettings()` - Get system settings (feature flags, remote config, maintenance mode)

---

### 2. Admin Backend API

**Location**: `/admin-backend/src/routes/`

**Base URL**: `https://orabeta-admin.vercel.app` (or configured base URL)

**Authentication**: JWT tokens (obtained via Firebase token exchange)

#### Authentication Routes (`/api/admin/auth`)
- ✅ `POST /login` - Admin login (Firebase token or email/password)
- ✅ `GET /me` - Get current admin user
- ✅ `POST /refresh` - Refresh JWT token

#### Admin Routes (`/api/admin/*`)

**User Management**:
- ✅ `GET /users` - Get all users (with filters, sorting, pagination)
- ✅ `GET /users/:userId` - Get specific user details
- ✅ `GET /users/:userId/activity` - Get user activity log
- ✅ `GET /users/:userId/posts` - Get user's posts
- ✅ `POST /users/ban` - Ban a user
- ✅ `POST /users/unban` - Unban a user
- ✅ `POST /users/:userId/warn` - Warn a user
- ✅ `POST /users/:userId/temp-ban` - Temporarily ban a user
- ✅ `POST /users/bulk` - Bulk user operations
- ✅ `PUT /users/:userId/role` - Update user role
- ✅ `DELETE /users/:userId` - Delete user
- ✅ `GET /users/export` - Export users to CSV

**Analytics**:
- ✅ `GET /analytics` - Get analytics data (period: 7d, 30d, 90d, all)

**Moderation**:
- ✅ `GET /moderation/queue` - Get moderation queue
- ✅ `POST /moderation/approve` - Approve a post
- ✅ `POST /moderation/reject` - Reject a post
- ✅ `POST /moderation/flag` - Flag a post

**Posts/Content Management**:
- ✅ `GET /posts` - Get posts (with filters, search, pagination)
- ✅ `GET /posts/:id` - Get specific post details
- ✅ `PUT /posts/:id` - Update post
- ✅ `DELETE /posts/:id` - Delete post
- ✅ `POST /posts/bulk` - Bulk post operations
- ✅ `POST /posts/upload-image` - Upload post image
- ✅ `POST /posts/bulk-create` - Bulk create posts

**Ban Appeals**:
- ✅ `GET /appeals` - Get ban appeals
- ✅ `POST /appeals/:appealId/review` - Review ban appeal

**Notifications**:
- ✅ `POST /notifications` - Create notification
- ✅ `GET /notifications` - List notifications
- ✅ `GET /notifications/:id` - Get notification details
- ✅ `POST /notifications/:id/send` - Send notification

**Welcome Images**:
- ✅ `GET /welcome-images` - Get welcome images
- ✅ `POST /welcome-images` - Upload welcome image
- ✅ `DELETE /welcome-images/:id` - Delete welcome image
- ✅ `PUT /welcome-images/reorder` - Reorder welcome images

**Settings**:
- ✅ `GET /settings` - Get system settings
- ✅ `POST /settings` - Update system settings

#### Reports Routes (`/api/reports/*`)
- ✅ `POST /posts/:id` - Report a post (public, uses Firebase token)
- ✅ `GET /my-reports` - Get user's reports (public, uses Firebase token)

---

### 3. Admin Dashboard (Web)

**Location**: `/admin-dashboard/`

**URL**: `https://dashboard.ora.riceboxai.com` (or configured URL)

**Technology**: Vue.js with Tailwind CSS

**Pages**:

1. **Users** (`/users`)
   - User list (table/card view)
   - Filters (status, search, date range, activity level)
   - Sorting (createdAt, email, displayName, followerCount, postCount)
   - Pagination
   - User actions: ban/unban, warn, temp ban, view details, export
   - Bulk operations

2. **Moderation** (`/moderation`)
   - Post moderation queue (pending, flagged, all)
   - Ban appeals
   - Actions: approve, reject, flag posts

3. **Content** (`/content`)
   - Post list (grid/list view)
   - Search and filters
   - Bulk operations (approve, reject, flag, delete)
   - Bulk upload
   - Post editing

4. **Analytics** (`/analytics`)
   - Summary cards (users, posts, likes, comments)
   - Period selector (7d, 30d, 90d, all)
   - Charts and metrics

5. **Notifications** (`/notifications`)
   - Create notifications
   - List notifications (draft, scheduled, sending, sent, failed)
   - Send notifications
   - View notification stats

6. **Settings** (`/settings`)
   - Feature flags (syncs to Firebase Remote Config)
   - Remote config (key-value pairs)
   - Maintenance mode

---

## Feature Mapping: SDK vs Backend vs Dashboard

### ✅ Fully Implemented (SDK + Backend + Dashboard)

| Feature | SDK | Backend | Dashboard |
|---------|-----|---------|-----------|
| Admin Login | ✅ | ✅ | ✅ |
| Get Users | ✅ | ✅ | ✅ |
| Ban/Unban User | ✅ | ✅ | ✅ |
| Get Analytics | ✅ | ✅ | ✅ |
| Moderation Queue | ✅ | ✅ | ✅ |
| Approve/Reject/Flag Post | ✅ | ✅ | ✅ |
| Report Post | ✅ | ✅ | ❌ (iOS only) |
| Get My Reports | ✅ | ✅ | ❌ (iOS only) |
| Get System Settings | ✅ | ✅ | ✅ |

### ⚠️ Backend Only (Not in SDK)

| Feature | Backend | Dashboard | SDK |
|---------|---------|-----------|-----|
| Get User Details | ✅ | ✅ | ❌ |
| Get User Activity | ✅ | ✅ | ❌ |
| Get User Posts | ✅ | ✅ | ❌ |
| Warn User | ✅ | ✅ | ❌ |
| Temp Ban User | ✅ | ✅ | ❌ |
| Bulk User Operations | ✅ | ✅ | ❌ |
| Update User Role | ✅ | ✅ | ❌ |
| Delete User | ✅ | ✅ | ❌ |
| Export Users | ✅ | ✅ | ❌ |
| Get Posts | ✅ | ✅ | ❌ |
| Get Post Details | ✅ | ✅ | ❌ |
| Update Post | ✅ | ✅ | ❌ |
| Delete Post | ✅ | ✅ | ❌ |
| Bulk Post Operations | ✅ | ✅ | ❌ |
| Upload Post Image | ✅ | ✅ | ❌ |
| Bulk Create Posts | ✅ | ✅ | ❌ |
| Ban Appeals | ✅ | ✅ | ❌ |
| Create Notifications | ✅ | ✅ | ❌ |
| List Notifications | ✅ | ✅ | ❌ |
| Send Notifications | ✅ | ✅ | ❌ |
| Welcome Images | ✅ | ✅ | ❌ |
| Update Settings | ✅ | ✅ | ❌ |

---

## How They Connect

### Authentication Flow

```
iOS App (Firebase Auth)
    ↓ (Firebase ID Token)
Admin SDK login()
    ↓ (POST /api/admin/auth/login)
Admin Backend
    ↓ (Verify Firebase Token, Create/Link AdminUser)
    ↓ (Generate JWT Token)
    ↓ (Return JWT + Admin Info)
Admin SDK
    ↓ (Store JWT Token)
iOS App (Authenticated)
```

### Admin Operations Flow

```
iOS App
    ↓ (Uses AdminClient with stored JWT)
Admin SDK Method
    ↓ (HTTP Request with Bearer Token)
Admin Backend
    ↓ (Verify JWT, Check Role Permissions)
    ↓ (Query/Update Firestore)
    ↓ (Return Response)
Admin SDK
    ↓ (Decode Response)
iOS App
```

### Public Reporting Flow (No Admin Auth Required)

```
iOS App (Regular User)
    ↓ (Firebase ID Token)
Admin SDK reportPost()
    ↓ (POST /api/reports/posts/:id with Firebase Token)
Admin Backend
    ↓ (Verify Firebase Token)
    ↓ (Create Report in Firestore)
    ↓ (Update Post Status to 'pending')
    ↓ (Return Success)
iOS App
```

### Dashboard Flow

```
Web Dashboard (Vue.js)
    ↓ (Firebase Auth)
    ↓ (POST /api/admin/auth/login)
Admin Backend
    ↓ (Return JWT Token)
Web Dashboard
    ↓ (Store JWT in localStorage/session)
    ↓ (Use JWT for all API calls)
Admin Backend
    ↓ (Return Data)
Web Dashboard
    ↓ (Render UI)
```

---

## iOS App Usage

### Where SDK is Used

1. **AdminDashboardView** (`OraBeta/Views/Admin/AdminDashboardView.swift`)
   - Shows analytics summary
   - Shows moderation queue count
   - Shows user count
   - Provides links to web dashboard
   - Uses: `login()`, `getAnalytics()`, `getModerationQueue()`, `getUsers()`

2. **ReportPostSheet** (`OraBeta/Views/ReportPostSheet.swift`)
   - Allows users to report posts
   - Uses: `reportPost()` (public endpoint with Firebase token)

3. **ReportedPostsView** (`OraBeta/Views/ReportedPostsView.swift`)
   - Shows user's reported posts
   - Uses: `getMyReports()` (public endpoint with Firebase token)

---

## Architectural Observations

### ✅ Strengths

1. **Clear Separation of Concerns**
   - iOS SDK provides clean abstraction
   - Backend handles all business logic
   - Dashboard provides rich UI for complex operations

2. **Consistent Authentication**
   - Single authentication flow (Firebase → JWT)
   - Role-based access control in backend
   - Public endpoints for user reporting (Firebase token)

3. **SDK Pattern Consistency**
   - Follows established SDK pattern (like Waitlist SDK)
   - Clean async/await API
   - Proper error handling

4. **Web Dashboard for Complex Operations**
   - Better UX for bulk operations
   - Rich filtering and search
   - Better suited for detailed admin tasks

### ⚠️ Gaps and Issues

1. **SDK Coverage is Limited**
   - Many backend endpoints not exposed in SDK
   - iOS app can only do basic admin operations
   - Complex operations require web dashboard

2. **No Settings Update in SDK**
   - Can read settings but not update
   - Settings updates only via web dashboard

3. **No Post Management in SDK**
   - Cannot view/edit/delete posts from iOS
   - Post management only via web dashboard

4. **No Notification Management in SDK**
   - Cannot create/send notifications from iOS
   - Notification management only via web dashboard

5. **No User Detail Operations in SDK**
   - Cannot view user details, activity, or posts from iOS
   - Limited to basic ban/unban operations

6. **Inconsistent Feature Parity**
   - Dashboard has many features SDK doesn't
   - iOS admin experience is limited compared to web

---

## Architectural Recommendations

### 1. **Expand SDK Coverage** (High Priority)

Add missing SDK methods for commonly needed operations:

```swift
// User Management
func getUserDetails(userId: String) async throws -> AdminUserInfo
func getUserActivity(userId: String) async throws -> UserActivityResponse
func getUserPosts(userId: String, limit: Int, offset: Int) async throws -> PostsResponse
func warnUser(userId: String, reason: String) async throws
func tempBanUser(userId: String, duration: Int, reason: String) async throws

// Post Management
func getPosts(limit: Int, offset: Int, filters: PostFilters?) async throws -> PostsResponse
func getPostDetails(postId: String) async throws -> PostDetails
func updatePost(postId: String, updates: PostUpdate) async throws
func deletePost(postId: String) async throws

// Settings
func updateSystemSettings(settings: SystemSettings) async throws

// Notifications (if needed on iOS)
func createNotification(notification: NotificationCreate) async throws -> NotificationResponse
func getNotifications() async throws -> NotificationsResponse
```

### 2. **Consider Feature Scope** (Medium Priority)

**Decision Point**: Should iOS app have full admin capabilities or remain limited?

**Option A: Keep iOS Limited (Current Approach)**
- ✅ Pros: Simpler SDK, less maintenance, better UX for complex tasks on web
- ❌ Cons: Admins need to switch to web for many operations

**Option B: Full Feature Parity**
- ✅ Pros: Complete admin capabilities on mobile
- ❌ Cons: Complex SDK, harder to maintain, mobile UX challenges for bulk operations

**Recommendation**: **Option A with selective expansion**
- Add commonly needed features (user details, post management)
- Keep bulk operations and complex workflows on web
- iOS serves as "mobile admin companion" rather than full replacement

### 3. **Improve Error Handling** (Medium Priority)

- Add more specific error types in SDK
- Provide better error messages
- Handle network failures gracefully
- Add retry logic for transient failures

### 4. **Add Caching** (Low Priority)

- Cache analytics data (refresh every 5 minutes)
- Cache user list (with invalidation on updates)
- Reduce API calls and improve performance

### 5. **Add Deep Linking** (Low Priority)

- Deep links from iOS to specific web dashboard pages
- Example: `dashboard.ora.riceboxai.com/users/:userId` from iOS
- Improves workflow between iOS and web

### 6. **Documentation** (High Priority)

- Document all SDK methods with examples
- Document backend API endpoints
- Document authentication flow
- Document error codes and handling

### 7. **Testing** (High Priority)

- Unit tests for SDK methods
- Integration tests for backend endpoints
- E2E tests for critical admin workflows

---

## Security Considerations

### ✅ Current Security Measures

1. **Authentication**
   - Firebase token verification
   - JWT token expiration (24h)
   - Role-based access control

2. **Authorization**
   - Role checks on backend (`requireRole()` middleware)
   - Different roles: `super_admin`, `moderator`, `viewer`

3. **Rate Limiting**
   - Auth rate limiting
   - API rate limiting

### ⚠️ Recommendations

1. **Token Refresh**
   - SDK should handle token refresh automatically
   - Currently requires manual re-login after 24h

2. **Audit Logging**
   - Backend has `logActivity` middleware
   - Ensure all sensitive operations are logged

3. **Input Validation**
   - Validate all inputs in SDK before sending
   - Backend should also validate (defense in depth)

---

## Data Flow Summary

### Admin Operations
```
iOS App → Admin SDK → Admin Backend → Firestore → Response
```

### User Reporting (Public)
```
iOS App → Admin SDK → Reports Backend → Firestore → Response
```

### Web Dashboard
```
Web Dashboard → Admin Backend → Firestore → Response
```

---

## Conclusion

The current architecture is well-designed with clear separation of concerns. The iOS SDK provides basic admin capabilities, while the web dashboard handles complex operations. 

**Key Recommendations**:
1. Expand SDK with commonly needed features (user details, post management)
2. Keep bulk operations on web dashboard
3. Improve documentation
4. Add comprehensive testing
5. Consider token refresh mechanism

The system is production-ready but could benefit from expanded SDK coverage for better mobile admin experience.

