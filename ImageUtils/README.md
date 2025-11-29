# ImageUtils

A thread-safe, actor-based image processing utility for Swift/iOS with optimized compression, resizing, and thumbnail generation.

## Features

- **Thread-Safe**: Uses Swift actors for safe concurrent access
- **Optimized Compression**: Automatic quality adjustment based on image size
- **Efficient Thumbnails**: Fast thumbnail generation using UIGraphicsImageRenderer
- **Memory Management**: Uses autoreleasepool for efficient memory handling
- **Parallel Processing**: Processes full image and thumbnail concurrently

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../ImageUtils")
]
```

Or add it as a local package in Xcode:
1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to the ImageUtils directory

## Usage

### Basic Image Compression

```swift
import ImageUtils

let processor = ImageProcessor.shared

// Compress an image
if let imageData = await processor.compressImage(image) {
    // Use compressed data
}

// Compress with max dimension (resizes if needed)
if let imageData = await processor.compressImage(image, maxDimension: 1920) {
    // Use compressed data
}
```

### Thumbnail Generation

```swift
import ImageUtils

let processor = ImageProcessor.shared

// Create a thumbnail (default: 400x400)
if let thumbnail = await processor.createThumbnail(image) {
    // Use thumbnail
}

// Create thumbnail with custom size
let customSize = CGSize(width: 200, height: 200)
if let thumbnail = await processor.createThumbnail(image, maxSize: customSize) {
    // Use thumbnail
}
```

### Process Full Image and Thumbnail

```swift
import ImageUtils

let processor = ImageProcessor.shared

// Process both full image and thumbnail in parallel
if let processed = await processor.processImage(image) {
    let fullImageData = processed.fullImageData
    let thumbnailData = processed.thumbnailData
    let width = processed.width
    let height = processed.height
    
    // Use the processed data
}
```

### Convert Data to UIImage

```swift
import ImageUtils

let processor = ImageProcessor.shared

// Convert image data back to UIImage
if let image = processor.image(from: imageData) {
    // Use image
}
```

## Compression Quality

The processor automatically adjusts compression quality based on image size:

- **>12MP**: 0.65 (aggressive compression)
- **6-12MP**: 0.75 (moderate compression)
- **<6MP**: 0.85 (high quality)

## Performance

- Uses `UIGraphicsImageRenderer` for efficient rendering
- Processes full image and thumbnail in parallel
- Uses `autoreleasepool` for memory management
- Actor-based for thread safety

## Architecture

The package consists of:

- **`ImageProcessor`**: Actor-based image processor with singleton pattern

## Thread Safety

All operations are thread-safe through Swift actors. The `ImageProcessor` is an actor, ensuring that all image processing operations are serialized and safe for concurrent access.

## Memory Management

The processor uses `autoreleasepool` blocks to ensure efficient memory management during image processing operations, preventing memory spikes during compression and resizing.

## Migration from Local Implementation

If you're migrating from a local implementation:

1. Add the package to your project
2. Import `ImageUtils` where needed
3. Replace local `ImageProcessor` references with `ImageUtils.ImageProcessor`
4. Or use the compatibility typealias: `ImageProcessor = ImageUtils.ImageProcessor`

The API remains the same, so minimal code changes are required.






