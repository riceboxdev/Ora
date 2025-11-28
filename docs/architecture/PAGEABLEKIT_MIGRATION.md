# PageableKit Package Migration Guide

This document describes the migration from the local pagination implementation to the `PageableKit` Swift package.

## Overview

The pagination utilities have been extracted into a standalone Swift package (`PageableKit`) to improve reusability and make the pagination protocol generic and backend-agnostic.

## Package Location

The package is located at: `/Users/nickrogers/DEV/OraBeta/PageableKit/`

## Adding the Package to Xcode

1. Open your Xcode project
2. Select your project in the navigator
3. Select your app target
4. Go to the "Package Dependencies" tab
5. Click the "+" button
6. Click "Add Local..." 
7. Navigate to `/Users/nickrogers/DEV/OraBeta/PageableKit/`
8. Click "Add Package"

Alternatively, you can add it via File → Add Packages... → Add Local...

## What Changed

### Generic PageInfo

The `PageInfo` type is now generic over the cursor type:

**Before:**
```swift
struct PageInfo {
    let endCursor: QueryDocumentSnapshot?
    let hasNextPage: Bool
}
```

**After:**
```swift
struct PageInfo<Cursor> {
    let endCursor: Cursor?
    let hasNextPage: Bool
}
```

### Firestore Compatibility

For Firestore-specific code, a typealias is provided:

```swift
typealias PageInfo = PageInfo<QueryDocumentSnapshot>
```

This maintains backward compatibility with existing code.

### Generic Pageable Protocol

The `Pageable` protocol is now generic:

**Before:**
```swift
protocol Pageable {
    associatedtype Value: Identifiable & Hashable
    func loadPage(pageInfo: PageInfo?, size: Int) async throws -> (values: [Value], pageInfo: PageInfo)
}
```

**After:**
```swift
protocol Pageable {
    associatedtype Value: Identifiable & Hashable
    associatedtype Cursor
    func loadPage(pageInfo: PageInfo<Cursor>?, size: Int) async throws -> (values: [Value], pageInfo: PageInfo<Cursor>)
}
```

For Firestore, the cursor type is `QueryDocumentSnapshot`, so existing implementations continue to work.

## Backward Compatibility

The old pagination files have been updated to re-export from the package:

- `Utils/Pageable.swift` - Re-exports `PageableKit.Pageable` with Firestore cursor type
- `Utils/PageInfo.swift` - Typealias for `PageInfo<QueryDocumentSnapshot>`

This means:
- **Existing code continues to work** without changes
- No need to update imports in existing files
- The old files act as compatibility shims

## Files Updated

1. `Utils/Pageable.swift` - Now re-exports from `PageableKit` with Firestore-specific cursor
2. `Utils/PageInfo.swift` - Now typealias for `PageInfo<QueryDocumentSnapshot>`

## Files That Stay in App

These files remain in the app as they are app-specific:

- `ViewModels/PagingViewModel.swift` - SwiftUI ViewModel (app-specific)
- `Utils/DiscoverFeedPageable.swift` - App-specific implementation

## Using the Package Directly

If you want to use the package directly (for non-Firestore backends):

```swift
import PageableKit

// For a REST API with string tokens
typealias TokenPageInfo = PageInfo<String>

struct RESTPageable: Pageable {
    typealias Value = MyItem
    typealias Cursor = String
    
    func loadPage(pageInfo: PageInfo<String>?, size: Int) async throws -> (values: [MyItem], pageInfo: PageInfo<String>) {
        // Implementation
    }
}
```

## Package Structure

```
PageableKit/
├── Package.swift
├── README.md
├── Sources/
│   └── PageableKit/
│       ├── Pageable.swift
│       └── PageInfo.swift
└── Tests/
    └── PageableKitTests/
        └── PageableTests.swift
```

## Testing

After adding the package to Xcode:

1. Build the project (Cmd+B)
2. Verify no compilation errors
3. Run the app and verify pagination works as expected
4. Test that `DiscoverFeedPageable` and `PagingViewModel` work correctly

## Troubleshooting

### Package Not Found

If you see "No such module 'PageableKit'":

1. Make sure the package is added to your target's dependencies
2. Clean build folder (Cmd+Shift+K)
3. Rebuild (Cmd+B)

### Type Conflicts

If you see type conflicts:

1. Remove any duplicate imports
2. Use `import PageableKit` directly instead of relying on re-exports
3. Check that old pagination files are using typealiases correctly

### Cursor Type Mismatch

If you see errors about cursor types:

1. Make sure you're using `PageInfo` (the typealias) for Firestore code
2. For other backends, use `PageInfo<YourCursorType>` explicitly
3. Check that your `Pageable` implementation specifies the correct `Cursor` type

## Future Migration

Eventually, you can:

1. Remove the compatibility shim files (`Utils/Pageable.swift`, `Utils/PageInfo.swift`)
2. Update all files to `import PageableKit` directly
3. Use `PageInfo<QueryDocumentSnapshot>` explicitly instead of the typealias

For now, the compatibility shims ensure a smooth transition with no breaking changes.



