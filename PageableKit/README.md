# PageableKit

A generic pagination protocol and utilities for Swift, inspired by Relay's pagination pattern.

## Features

- **Generic Protocol**: Works with any cursor type (document snapshots, offsets, tokens, etc.)
- **Type-Safe**: Uses Swift generics for type safety
- **SwiftUI Compatible**: Values must be `Identifiable & Hashable` for SwiftUI integration
- **Simple API**: Clean, easy-to-use pagination interface

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../PageableKit")
]
```

Or add it as a local package in Xcode:
1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to the PageableKit directory

## Usage

### Basic Protocol Implementation

```swift
import PageableKit

struct MyPageable: Pageable {
    typealias Value = MyItem
    typealias Cursor = String  // Could be any type: QueryDocumentSnapshot, Int, String, etc.
    
    func loadPage(pageInfo: PageInfo<String>?, size: Int) async throws -> (values: [MyItem], pageInfo: PageInfo<String>) {
        let cursor = pageInfo?.endCursor
        // Load your data using the cursor
        let items = try await loadItems(after: cursor, limit: size)
        
        // Determine if there are more pages
        let hasNextPage = items.count >= size
        let newCursor = items.last?.id
        
        let newPageInfo = PageInfo.withCursor(newCursor, hasNextPage: hasNextPage)
        return (items, newPageInfo)
    }
}
```

### Firestore Example

```swift
import PageableKit
import FirebaseFirestore

typealias FirestorePageInfo = PageInfo<QueryDocumentSnapshot>

struct FirestorePageable: Pageable {
    typealias Value = Post
    typealias Cursor = QueryDocumentSnapshot
    
    func loadPage(pageInfo: FirestorePageInfo?, size: Int) async throws -> (values: [Post], pageInfo: FirestorePageInfo) {
        var query = Firestore.firestore().collection("posts")
            .limit(to: size)
        
        if let cursor = pageInfo?.endCursor {
            query = query.start(afterDocument: cursor)
        }
        
        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents.compactMap { Post(from: $0) }
        
        let hasNextPage = snapshot.documents.count >= size
        let lastDocument = snapshot.documents.last
        
        let newPageInfo = FirestorePageInfo.withCursor(lastDocument, hasNextPage: hasNextPage)
        return (posts, newPageInfo)
    }
}
```

### REST API Example

```swift
import PageableKit

typealias TokenPageInfo = PageInfo<String>

struct RESTPageable: Pageable {
    typealias Value = User
    typealias Cursor = String  // API token
    
    func loadPage(pageInfo: TokenPageInfo?, size: Int) async throws -> (values: [User], pageInfo: TokenPageInfo) {
        let token = pageInfo?.endCursor
        let response = try await api.getUsers(after: token, limit: size)
        
        let hasNextPage = response.items.count >= size
        let newPageInfo = TokenPageInfo.withCursor(response.nextToken, hasNextPage: hasNextPage)
        
        return (response.items, newPageInfo)
    }
}
```

## PageInfo API

```swift
// Create initial page info
let initialPageInfo = PageInfo<String>.initial(hasNextPage: true)

// Create page info with cursor
let pageInfo = PageInfo.withCursor("cursor123", hasNextPage: true)

// Access properties
let cursor = pageInfo.endCursor
let hasMore = pageInfo.hasNextPage
```

## Architecture

The package consists of:

- **`Pageable`**: Protocol for paginated data sources
- **`PageInfo<Cursor>`**: Generic page metadata with cursor support

## Type Safety

The generic `Cursor` type allows you to use any type as a cursor:
- `QueryDocumentSnapshot` for Firestore
- `String` for API tokens
- `Int` for offsets
- Custom types for your specific needs

## Migration from Local Implementation

If you're migrating from a local implementation:

1. Add the package to your project
2. Import `PageableKit` where needed
3. Update your `PageInfo` type to use the generic version: `PageInfo<YourCursorType>`
4. Update your `Pageable` implementations to use the generic protocol

For Firestore-specific code, you can create a typealias:
```swift
typealias PageInfo = PageInfo<QueryDocumentSnapshot>
```



