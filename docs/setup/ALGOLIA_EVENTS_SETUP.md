# Algolia Events API Setup

This document describes the Algolia Events API integration for personalization in the OraBeta app.

## Overview

The Algolia Events API has been integrated to track user interactions and power Algolia's Personalization API. This allows Algolia to learn from user behavior and provide personalized search results and recommendations.

## Configuration

### 1. Update Config.swift

Add your Algolia credentials to `OraBeta/Utils/Config.swift`:

```swift
// Algolia Configuration
static let algoliaApplicationID = "YOUR_ALGOLIA_APP_ID"
static let algoliaAPIKey = "YOUR_ALGOLIA_API_KEY" // Use Search-Only API Key for client-side
static let algoliaIndexName = "posts" // Your Algolia index name for posts
```

**Important**: 
- Use a **Search-Only API Key** for client-side tracking (not your Admin API Key)
- The index name should match your Algolia index where posts are stored

### 2. Get Your Algolia Credentials

1. Go to [Algolia Dashboard](https://www.algolia.com/dashboard)
2. Select your application
3. Go to **Settings** → **API Keys**
4. Copy your **Application ID** and create a **Search-Only API Key** if you don't have one
5. Note your index name (or create one if needed)

## Implementation Details

### Service: AlgoliaInsightsService

A singleton service (`AlgoliaInsightsService.shared`) handles all Algolia event tracking:

- **Location**: `OraBeta/Models/AlgoliaInsightsService.swift`
- **Initialization**: Automatically initialized when user logs in (via `AuthViewModel`)
- **Documentation**: https://www.algolia.com/doc/libraries/sdk/methods/insights/push-events

### Event Types Tracked

#### 1. View Events
- **When**: User views a post detail page
- **Location**: `PostDetailView.swift`
- **Method**: `trackView(objectID:)`

#### 2. Click Events
- **When**: User taps on a post in a grid/list
- **Location**: `PostGrid.swift`
- **Method**: `trackClick(objectID:position:queryID:)`

#### 3. Conversion Events

##### Like Events
- **When**: User likes a post
- **Location**: `PostDetailViewModel.swift` → `toggleLike()`
- **Method**: `trackLike(objectID:)`
- **Event Name**: "Post Liked"

##### Save Events
- **When**: User saves a post to a board
- **Location**: `PostDetailViewModel.swift` → `saveToBoard()`
- **Method**: `trackSave(objectID:)`
- **Event Name**: "Post Saved"

##### Comment Events
- **When**: User comments on a post
- **Location**: `CommentSheet.swift` → `addComment()`
- **Method**: `trackComment(objectID:)`
- **Event Name**: "Post Commented"

## Integration Points

### 1. Initialization
- **File**: `OraBeta/Models/AuthViewModel.swift`
- **When**: After user successfully authenticates with Stream
- **Code**: `AlgoliaInsightsService.shared.initialize()`

### 2. View Tracking
- **File**: `OraBeta/Views/PostDetailView.swift`
- **When**: Post detail view appears
- **Code**: `await AlgoliaInsightsService.shared.trackView(objectID: post.id)`

### 3. Click Tracking
- **File**: `OraBeta/Views/PostGrid.swift`
- **When**: User taps on a post thumbnail
- **Code**: `await AlgoliaInsightsService.shared.trackClick(objectID: post.id, position: index)`

### 4. Like Tracking
- **File**: `OraBeta/ViewModels/PostDetailViewModel.swift`
- **When**: User successfully likes a post
- **Code**: `await AlgoliaInsightsService.shared.trackLike(objectID: post.id)`

### 5. Save Tracking
- **File**: `OraBeta/ViewModels/PostDetailViewModel.swift`
- **When**: User successfully saves a post to a board
- **Code**: `await AlgoliaInsightsService.shared.trackSave(objectID: post.id)`

### 6. Comment Tracking
- **File**: `OraBeta/Views/CommentSheet.swift`
- **When**: User successfully adds a comment
- **Code**: `await AlgoliaInsightsService.shared.trackComment(objectID: post.id)`

## User Token

The service automatically uses the current Firebase Auth user ID as the `userToken` for event tracking. This allows Algolia to:
- Track events per user
- Build user profiles for personalization
- Provide personalized search results

## Event Data Structure

Each event includes:
- **indexName**: The Algolia index name (from Config)
- **userToken**: Firebase Auth user ID
- **objectIDs**: Array containing the post ID
- **positions**: Optional position in list (for views/clicks)
- **queryID**: Optional query ID (for search result clicks)
- **eventName**: Name of conversion event (for conversions)

## Testing

1. **Configure Credentials**: Update `Config.swift` with your Algolia credentials
2. **Build and Run**: The app should compile without errors
3. **Test Events**: 
   - View a post → Check Algolia dashboard for view event
   - Click a post → Check for click event
   - Like a post → Check for conversion event
   - Save a post → Check for conversion event
   - Comment on a post → Check for conversion event

## Monitoring Events

1. Go to [Algolia Dashboard](https://www.algolia.com/dashboard)
2. Select your application
3. Go to **Analytics** → **Insights**
4. View incoming events in real-time

## Personalization Setup

After events are being tracked:

1. Go to **Personalization** in Algolia Dashboard
2. Configure which events should influence personalization
3. Set up personalization strategies
4. Enable personalization in your search queries

## Troubleshooting

### Events Not Appearing

1. **Check Credentials**: Verify `Config.swift` has correct values
2. **Check Initialization**: Ensure user is logged in (service initializes on login)
3. **Check Console**: Look for Algolia error messages in Xcode console
4. **Check Network**: Ensure device has internet connection
5. **Check Algolia Dashboard**: Verify events are being received

### Common Issues

- **"Algolia credentials not configured"**: Update `Config.swift` with your credentials
- **"Failed to initialize"**: Check that API key is valid and has Insights permissions
- **Events not tracked**: Ensure user is authenticated (userToken is required)

## Next Steps

1. **Configure Algolia Index**: Ensure your posts are indexed in Algolia with the correct object IDs
2. **Enable Personalization**: Set up personalization in Algolia Dashboard
3. **Test Personalization**: Use Algolia search with personalization enabled
4. **Monitor Performance**: Track how personalization affects user engagement

## References

- [Algolia Events API Documentation](https://www.algolia.com/doc/libraries/sdk/methods/insights/push-events)
- [Algolia Personalization Guide](https://www.algolia.com/doc/guides/personalization/what-is-personalization/)
- [Algolia Swift SDK](https://github.com/algolia/algoliasearch-client-swift)

