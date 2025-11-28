# Post Data Structure for Firebase Firestore

## Collection: `posts`

### Document Structure

Each post is stored as a document in the `posts` collection. The document ID should be a unique identifier (you can use Firestore's auto-generated ID or create your own).

### Required Fields

```typescript
{
  activityId: string;        // Same as document ID (for compatibility)
  userId: string;            // Firebase Auth UID of the post creator
  imageUrl: string;         // Full image URL (from Cloudinary)
  thumbnailUrl: string;      // Thumbnail image URL (from Cloudinary)
  caption: string | null;   // Post caption/description (can be null)
  tags: string[];          // Array of tag strings (can be empty array)
  categories: string[];     // Array of category strings (can be empty array)
  createdAt: Timestamp;     // Server timestamp (use FieldValue.serverTimestamp())
  updatedAt: Timestamp;     // Server timestamp (use FieldValue.serverTimestamp())
}
```

### Optional Fields

```typescript
{
  imageWidth?: number;      // Image width in pixels
  imageHeight?: number;    // Image height in pixels
  edited?: boolean;        // Whether post was edited (set to true on updates)
}
```

## Example: Creating a Post with Firebase SDK (Swift)

```swift
import FirebaseFirestore

func createPost(
    userId: String,
    imageUrl: String,
    thumbnailUrl: String,
    imageWidth: Int?,
    imageHeight: Int?,
    caption: String?,
    tags: [String],
    categories: [String]
) async throws -> String {
    let db = Firestore.firestore()
    
    // Create a new document reference (auto-generates ID)
    let postRef = db.collection("posts").document()
    let postId = postRef.documentID
    
    // Build post data
    var postData: [String: Any] = [
        "activityId": postId,
        "userId": userId,
        "imageUrl": imageUrl,
        "thumbnailUrl": thumbnailUrl,
        "caption": caption ?? NSNull(),
        "tags": tags,
        "categories": categories,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp()
    ]
    
    // Add optional image dimensions
    if let imageWidth = imageWidth {
        postData["imageWidth"] = imageWidth
    }
    if let imageHeight = imageHeight {
        postData["imageHeight"] = imageHeight
    }
    
    // Save to Firestore
    try await postRef.setData(postData)
    
    return postId
}
```

## Example: Creating a Post with Firebase SDK (JavaScript/TypeScript)

```typescript
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore';

async function createPost(
  userId: string,
  imageUrl: string,
  thumbnailUrl: string,
  imageWidth?: number,
  imageHeight?: number,
  caption?: string,
  tags: string[] = [],
  categories: string[] = []
): Promise<string> {
  const db = getFirestore();
  
  const postData: any = {
    activityId: '', // Will be set after document creation
    userId,
    imageUrl,
    thumbnailUrl,
    caption: caption || null,
    tags,
    categories,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  
  // Add optional image dimensions
  if (imageWidth !== undefined) {
    postData.imageWidth = imageWidth;
  }
  if (imageHeight !== undefined) {
    postData.imageHeight = imageHeight;
  }
  
  // Create document reference first to get ID
  const postRef = doc(collection(db, 'posts'));
  postData.activityId = postRef.id;
  
  // Save to Firestore
  await setDoc(postRef, postData);
  
  return postRef.id;
}
```

## Example: Updating a Post

```swift
func updatePost(
    postId: String,
    caption: String?,
    tags: [String]?,
    categories: [String]?
) async throws {
    let db = Firestore.firestore()
    let postRef = db.collection("posts").document(postId)
    
    var updateData: [String: Any] = [
        "updatedAt": FieldValue.serverTimestamp(),
        "edited": true
    ]
    
    if let caption = caption {
        updateData["caption"] = caption
    }
    if let tags = tags {
        updateData["tags"] = tags
    }
    if let categories = categories {
        updateData["categories"] = categories
    }
    
    try await postRef.updateData(updateData)
}
```

## Field Types

- `activityId`: String (same as document ID)
- `userId`: String (Firebase Auth UID)
- `imageUrl`: String (Cloudinary URL)
- `thumbnailUrl`: String (Cloudinary URL)
- `caption`: String or null
- `tags`: Array of strings (can be empty `[]`)
- `categories`: Array of strings (can be empty `[]`)
- `createdAt`: Firestore Timestamp (use `FieldValue.serverTimestamp()`)
- `updatedAt`: Firestore Timestamp (use `FieldValue.serverTimestamp()`)
- `imageWidth`: Number (optional)
- `imageHeight`: Number (optional)
- `edited`: Boolean (optional, set to `true` when post is edited)

## Notes

1. **Server Timestamps**: Always use `FieldValue.serverTimestamp()` for `createdAt` and `updatedAt` to ensure consistent timestamps across clients.

2. **Document ID**: The `activityId` field should match the document ID. You can either:
   - Use Firestore's auto-generated document ID and set `activityId` to match it
   - Generate your own unique ID and use it for both the document ID and `activityId`

3. **Null Values**: Use `NSNull()` in Swift or `null` in JavaScript for optional string fields like `caption`.

4. **Empty Arrays**: Use empty arrays `[]` for `tags` and `categories` if none are provided.

5. **Image Dimensions**: `imageWidth` and `imageHeight` are optional but recommended for proper image display and layout calculations.












