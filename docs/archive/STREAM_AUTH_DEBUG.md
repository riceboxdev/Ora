# Stream Authentication Debug Guide

## Current Error
```
GetOrCreateFeed failed with error: "stream-auth-type missing or invalid"
Status Code: 401
```

## Root Cause
The API key used to **generate** the token in Firebase Functions must **exactly match** the API key used to **initialize** the iOS client.

## Diagnostic Steps

### 1. Verify API Key Consistency

**Check Firebase Functions Environment:**
```bash
# Check your Firebase Functions environment variables
firebase functions:config:get
# OR in Firebase Console:
# Functions → Configuration → Environment Variables
# Look for: STREAM_API_KEY
```

**Check iOS Config:**
```swift
// In OraBeta/Utils/Config.swift
static let streamAPIKey = "qyfy876f96h9"
```

**⚠️ These MUST be identical!**

### 2. Verify Token Generation

The token should contain:
- `user_id` - Must match the user ID passed to FeedsClient
- `iat` (issued at) - Timestamp
- Signature that matches the API secret

### 3. Common Issues

1. **API Key Mismatch** - Token generated with key A, client uses key B
2. **Wrong Secret** - Token signed with secret that doesn't match the API key
3. **Expired Token** - Token has expired (check `exp` claim in JWT)
4. **User ID Mismatch** - Token `user_id` doesn't match FeedsClient user ID

## Solution

### Step 1: Verify Firebase Functions Environment

Ensure your Firebase Functions have the correct environment variables:

```bash
cd functions
firebase functions:config:set stream.api_key="YOUR_API_KEY" stream.api_secret="YOUR_API_SECRET"
firebase deploy --only functions
```

### Step 2: Verify iOS Config Matches

Ensure `Config.streamAPIKey` matches the API key in Firebase Functions:

```swift
// Config.swift
static let streamAPIKey = "YOUR_API_KEY" // Must match Firebase Functions STREAM_API_KEY
```

### Step 3: Check Stream Dashboard

1. Go to [Stream Dashboard](https://getstream.io/dashboard/)
2. Select your app
3. Verify:
   - API Key matches what you're using
   - Authentication is enabled (not developer tokens)
   - App ID matches `Config.streamAppId`

### Step 4: Test Token Generation

You can manually test the Firebase Function:

```swift
// In your app, after authentication:
let functions = Functions.functions()
let getStreamTokenFunction = functions.httpsCallable("ext-auth-activity-feeds-getStreamUserToken")
let result = try await getStreamTokenFunction.call()
let token = result.data as? String

// Decode and verify
if let payload = TokenDebugger.decodeJWT(token) {
    print("Token user_id: \(payload["user_id"])")
    print("Token API key (from signature): Check in Stream Dashboard")
}
```

## Debug Output

When you run the app, you should now see:
- Token debug information (user_id, expiration, etc.)
- API key being used
- User ID verification

Check the console output for:
- ✅ "User ID matches token" - Good!
- ⚠️ "User ID mismatch" - Problem!
- Token expiration status

## Next Steps

1. **Run the app with the new debug code**
2. **Check the console output** for token details
3. **Verify API keys match** between Firebase Functions and iOS Config
4. **Check Stream Dashboard** to confirm your API key and secret

## If Still Failing

1. Verify the Stream API secret in Firebase Functions matches your Stream Dashboard
2. Check if tokens have proper expiration (not expired)
3. Verify the Stream app configuration allows user tokens (not developer tokens)
4. Check Stream Dashboard → Authentication settings





























