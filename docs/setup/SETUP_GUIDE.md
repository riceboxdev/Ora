# OraBeta - Visual Discovery App Setup Guide

## Overview
OraBeta is a complete visual discovery and collection iOS app built with SwiftUI, Firebase Authentication, Stream Activity Feeds, and Cloudinary image storage.

## Features Implemented

### ✅ Authentication
- Firebase email/password authentication
- Auto-connect to Stream feeds on sign in/up
- Stream user token generation via Firebase Functions

### ✅ Feed System
- **Home Feed**: Following feed (timeline) and Discover feed toggle
- **User Feed**: Each user's personal posts
- **Category Feeds**: Browse by 16 different categories (Nature, Abstract, Space, etc.)
- **Discover Feed**: Global feed with all posts

### ✅ Upload System
- Photo library integration
- Image upload to Cloudinary (full size + thumbnail)
- Multi-category selection
- Title and description
- Automatic posting to user feed, category feeds, and discover feed

### ✅ Collections
- Create and manage collections (Boards)
- Add posts to collections
- Public/private collection support
- Stored in Firestore

### ✅ Social Features
- Follow/unfollow users
- View following list
- User profile pages
- Timeline feed aggregates followed users' posts

### ✅ Interactions
- Like posts (Stream reactions)
- Comment on posts (Stream reactions)
- Download images to Photos
- Share posts
- View post details

### ✅ UI/UX
- Modern SwiftUI design
- Tab-based navigation (Home, Discover, Upload, Collections, Profile)
- Grid layouts for posts
- Full-screen detail view
- Pull-to-refresh support
- Loading states and error handling

## Setup Instructions

### 1. Firebase Setup

#### a. Configure Firebase
Your Firebase project is already configured with:
- Authentication (Email/Password enabled)
- Cloud Functions for Stream token generation
- The `GoogleService-Info.plist` is already added to the project

#### b. Firebase Functions
Your Firebase Functions are already deployed with:
- `createStreamUser` - Creates Stream user when Firebase user is created
- `deleteStreamUser` - Deletes Stream user when Firebase user is deleted
- `getStreamUserToken` - Generates Stream tokens for authenticated users

Functions use environment variables:
- `STREAM_API_KEY`
- `STREAM_API_SECRET`
- `NAME_FIELD`, `EMAIL_FIELD`, `IMAGE_FIELD` (optional customization)

### 2. Stream Configuration

#### a. Update Config.swift
The Stream configuration is in `OraBeta/Utils/Config.swift`:

```swift
// Already configured:
static let streamAPIKey = "qyfy876f96h9"
static let streamAppId = "1442982"
```

#### b. Stream Dashboard Setup
1. Go to [Stream Dashboard](https://getstream.io/dashboard/)
2. Ensure your app has the following feed groups configured:
   - `user` - User's personal feed
   - `timeline` - Aggregated following feed (flat feed)
   - `discover` - Global discovery feed
   - `category_*` - Category feeds (created dynamically, e.g., `category_nature`)

### 3. Cloudinary Setup

#### a. Get Cloudinary Credentials
1. Sign up at [Cloudinary](https://cloudinary.com/)
2. Get your Cloud Name from the dashboard
3. Create an unsigned upload preset:
   - Settings → Upload → Upload presets
   - Click "Add upload preset"
   - Set Signing Mode to "Unsigned"
   - Configure folders if desired
   - Save and note the preset name

#### b. Update Config.swift
Update the Cloudinary configuration in `OraBeta/Utils/Config.swift`:

```swift
static let cloudinaryCloudName = "YOUR_CLOUD_NAME"
static let cloudinaryUploadPreset = "YOUR_UPLOAD_PRESET"
```

### 4. Firestore Setup

For collections feature, enable Cloud Firestore in your Firebase project:

1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Start in production mode (or test mode for development)
4. Choose a location

#### Firestore Rules (Recommended)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /collections/{collectionId} {
      // Allow users to read all public collections
      allow read: if resource.data.isPrivate == false;
      // Allow users to read their own collections (including private)
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      // Allow users to create, update, and delete their own collections
      allow create, update, delete: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

### 5. iOS Permissions

Add the following to your Info.plist (or in Xcode Target Settings → Info):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload images</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save images to your photo library</string>
```

**To add in Xcode:**
1. Select your project in Xcode
2. Select the OraBeta target
3. Go to Info tab
4. Add these keys under "Custom iOS Target Properties"

### 6. Dependencies

This project uses Swift Package Manager (SPM) for dependencies. The packages are already configured in the Xcode project:

- **StreamFeeds** - Stream activity feeds integration
- **Cloudinary** - Cloudinary iOS SDK for image management
- **Firebase** - Through cloudinary_ios dependencies

No additional installation required - Xcode will automatically resolve and download packages on first build.

### 7. Build and Run

1. Open `OraBeta.xcodeproj` in Xcode
2. Select your target device (iPhone 16 as preferred)
3. Build and run (Cmd + R)

## Project Structure

```
OraBeta/
├── Models/
│   ├── AuthService.swift           # Firebase authentication
│   ├── AuthViewModel.swift         # Auth state management
│   ├── StreamService.swift         # Stream feeds integration
│   ├── Post.swift                 # Post data model
│   ├── Board.swift                # Board/Collection data model
│   └── Category.swift             # Category enum
├── ViewModels/
│   ├── FeedViewModel.swift        # Feed loading logic
│   ├── UploadViewModel.swift     # Upload handling + Cloudinary
│   ├── CollectionsViewModel.swift # Collections management
│   ├── UserViewModel.swift        # User profile + follow logic
│   └── WallpaperActionsViewModel.swift # Like/comment logic
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── Feed/
│   │   ├── PostCardView.swift           # Post card component
│   │   ├── PostDetailView.swift         # Full screen detail
│   │   └── CategoryFeedView.swift       # Category-specific feed
│   ├── Discover/
│   │   ├── DiscoverView.swift           # Main discover page
│   │   └── CategoryGridView.swift       # Category browser
│   ├── Upload/
│   │   └── UploadView.swift             # Upload interface
│   ├── Collections/
│   │   ├── CollectionsListView.swift
│   │   ├── CollectionDetailView.swift
│   │   └── CreateCollectionView.swift
│   ├── Profile/
│   │   ├── UserProfileView.swift        # Other users
│   │   └── FollowingListView.swift
│   ├── Comments/
│   │   └── CommentsView.swift           # Comments sheet
│   ├── FeedView.swift                   # Main feed (Home tab)
│   ├── ProfileView.swift                # Current user profile
│   ├── MainTabView.swift                # Tab bar navigation
│   └── RootView.swift                   # Auth routing
├── Utils/
│   └── Config.swift                     # Configuration constants
└── OraBetaApp.swift                     # App entry point
```

## Stream Feed Architecture

### Feed Groups
- **user:USER_ID** - User's own posts
- **timeline:USER_ID** - Aggregated feed from followed users
- **discover:global** - All posts
- **category_CATEGORY_NAME:global** - Category-specific feeds

### Activity Structure
```json
{
  "actor": "USER_ID",
  "verb": "post",
  "object": "post:POST_ID",
  "foreign_id": "post:UNIQUE_ID",
  "data": {
    "postId": "string",
    "title": "string",
    "imageUrl": "string",
    "thumbnailUrl": "string",
    "categories": ["string"],
    "collections": ["string"],
    "metadata": {
      "width": int,
      "height": int,
      "aspectRatio": double,
      "dominantColors": ["string"]
    }
  }
}
```

### Reactions
- **like**: Heart reaction on posts
- **comment**: Comment with text data

## Testing Checklist

1. ✅ Sign up with email/password
2. ✅ Stream auto-connects (check Profile → Stream Status)
3. ✅ Upload an image with categories
4. ✅ View post in Home feed, Discover, and Category feed
5. ✅ Like and comment on posts
6. ✅ Follow another user
7. ✅ See followed user's posts in timeline
8. ✅ Create a board/collection
9. ✅ Download image to Photos
10. ✅ Sign out and sign back in

## Troubleshooting

### Stream Not Connected
- Check that Firebase Functions are deployed correctly
- Verify `STREAM_API_KEY` and `STREAM_API_SECRET` in Firebase Functions config
- Check Xcode console for error messages

### Upload Fails
- Verify Cloudinary credentials in Config.swift
- Ensure upload preset is "unsigned"
- Check network connectivity

### Collections Not Saving
- Verify Firestore is enabled in Firebase Console
- Check Firestore security rules
- Review Xcode console for Firestore errors

### Photos Not Downloading
- Ensure photo library permissions are added to Info.plist
- Grant permissions when prompted by iOS

## Next Steps / Future Enhancements

- [ ] Search functionality
- [ ] User mentions in comments
- [ ] Notifications for likes/comments/follows
- [ ] Category personalization
- [ ] Popular/Trending algorithm
- [ ] User badges/achievements
- [ ] Report/moderation system
- [ ] Board sharing
- [ ] Color-based search
- [ ] AI-powered recommendations

## Support

For issues or questions:
- Check Firebase Console logs
- Review Stream Dashboard activity
- Check Xcode console output
- Verify all API keys and credentials

## License

This project is for personal/educational use.

