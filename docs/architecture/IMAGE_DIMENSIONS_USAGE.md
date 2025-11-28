# Image Dimensions in Post Objects

## Overview
Image dimensions (`imageWidth` and `imageHeight`) are now fully integrated into the Post model and available throughout the app.

## Available Properties

### Direct Access
```swift
let post: Post

// Raw dimensions (optional)
if let width = post.imageWidth, let height = post.imageHeight {
    print("Image is \(width) × \(height) pixels")
}
```

### Computed Properties

#### Check if dimensions exist
```swift
if post.hasDimensions {
    // Dimensions are available
}
```

#### Get aspect ratio
```swift
if let ratio = post.aspectRatio {
    print("Aspect ratio: \(ratio)")
}
```

#### Get as CGSize
```swift
if let size = post.imageSize {
    print("Size: \(size.width) × \(size.height)")
}
```

#### Check orientation
```swift
if post.isLandscape {
    print("This is a landscape image")
}

if post.isPortrait {
    print("This is a portrait image")
}

if post.isSquare {
    print("This is a square image")
}
```

### Helper Methods

#### Get formatted dimensions text
```swift
let dimensionsText = post.dimensionsText
// Returns: "1920 × 1080" or "Dimensions unknown"
```

#### Get orientation text
```swift
let orientation = post.orientationText
// Returns: "Landscape", "Portrait", "Square", or "Unknown"
```

#### Calculate placeholder height
```swift
let width: CGFloat = 300
let height = post.placeholderHeight(forWidth: width)
// Returns appropriate height to maintain aspect ratio
```

## Usage Examples

### In SwiftUI Views

#### Using aspect ratio for placeholders
```swift
AsyncImage(url: URL(string: post.imageUrl)) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
} placeholder: {
    Rectangle()
        .fill(Color.gray.opacity(0.2))
        .aspectRatio(post.aspectRatio ?? 1, contentMode: .fit)
        .overlay {
            ProgressView()
        }
}
```

#### Conditional layout based on orientation
```swift
if post.isPortrait {
    // Use portrait-optimized layout
    VStack {
        PostImage(post: post)
        PostInfo(post: post)
    }
} else {
    // Use landscape-optimized layout
    HStack {
        PostImage(post: post)
        PostInfo(post: post)
    }
}
```

#### Display metadata
```swift
VStack(alignment: .leading) {
    Text(post.dimensionsText)
        .font(.caption)
    Text(post.orientationText)
        .font(.caption2)
        .foregroundColor(.secondary)
}
```

## Data Flow

### When Creating Posts
Image dimensions are automatically extracted from the uploaded image in `CreatePostView` and `AdminBulkUploadView`:

```swift
let imageWidth = Int(image.size.width)
let imageHeight = Int(image.size.height)

try await postService.createPost(
    userId: userId,
    imageUrl: imageUrl,
    thumbnailUrl: thumbnailUrl,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    caption: caption,
    tags: tags,
    categories: categories
)
```

### When Fetching Posts
Dimensions are included in the Stream activity data and parsed in `Post.from(activity:)`:

```swift
let imageWidth = custom?["imageWidth"] as? Int ?? custom?["width"] as? Int
let imageHeight = custom?["imageHeight"] as? Int ?? custom?["height"] as? Int
```

### Migrating Existing Posts
Use the Admin Dashboard migration function to add dimensions to posts that don't have them:

1. Open Settings → Admin Dashboard
2. Tap "Migrate Image Dimensions"
3. The migration downloads each image, extracts dimensions, and updates the post

## Where It's Used

### Currently Implemented
- ✅ `FeedPostView` - Uses aspect ratio for placeholder
- ✅ `PostDetailView` - Uses aspect ratio for placeholder
- ✅ Post model - Full dimension properties available
- ✅ Admin Dashboard - Migration function to add dimensions

### Potential Future Uses
- Grid layouts with proper spacing
- Image quality selection based on dimensions
- Analytics on image sizes
- Content recommendations based on orientation preferences
- Responsive layouts that adapt to image dimensions
