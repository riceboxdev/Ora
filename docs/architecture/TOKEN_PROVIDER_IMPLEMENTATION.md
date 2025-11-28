# Stream Token Provider Implementation

This document explains the Token Provider implementation following [Stream's official documentation](https://getstream.io/activity-feeds/docs/ios/tokens-and-authentication/).

## Overview

According to Stream's documentation:
> "A token provider is a function or class that you implement and that is responsible for requesting a new token from your own login infrastructure. The most common token provider implementation does an HTTP call to your backend with the ID of the user as well as a valid session id or secret needed to authenticate them."

## Implementation

### 1. StreamTokenProvider Class

Located in `OraBeta/Utils/StreamTokenProvider.swift`, this class implements the token provider pattern:

- **Purpose**: Provides fresh Stream tokens to the SDK whenever needed
- **Backend**: Calls Firebase Functions (`getStreamUserToken`) to get tokens
- **Authentication**: Uses Firebase Auth to validate user sessions
- **Pattern**: Follows Stream's documented token provider flow

### 2. How It Works

```
┌─────────────┐
│ Stream SDK  │
│ (iOS Client)│
└──────┬──────┘
       │ 1. Needs token (init, expired, refresh)
       │
       ▼
┌─────────────────────┐
│ StreamTokenProvider │
│   (Token Provider)   │
└──────┬──────────────┘
       │ 2. HTTP call to Firebase Functions
       │
       ▼
┌──────────────────────┐
│ Firebase Functions   │
│ getStreamUserToken   │
└──────┬───────────────┘
       │ 3. Validates Firebase Auth session
       │ 4. Generates Stream token using server SDK
       │
       ▼
┌──────────────────────┐
│ Stream Server SDK    │
│ createUserToken()    │
└──────┬───────────────┘
       │ 5. Returns JWT token
       │
       ▼
┌──────────────────────┐
│ Stream SDK           │
│ Uses token for API   │
└──────────────────────┘
```

### 3. Token Flow

1. **Initial Authentication**: 
   - User signs in with Firebase Auth
   - App calls `getStreamUserToken` Firebase Function
   - Receives initial token
   - Initializes `FeedsClient` with token and token provider

2. **Token Refresh**:
   - When token expires or SDK needs refresh
   - SDK automatically calls the token provider
   - Token provider calls Firebase Functions
   - Fresh token returned to SDK
   - SDK continues operations seamlessly

3. **Error Handling**:
   - If Firebase Auth session invalid → Returns error
   - If Firebase Function fails → Returns error
   - SDK handles errors appropriately

## Key Features

### ✅ Follows Stream Documentation
- Implements the exact pattern described in Stream's docs
- Uses HTTP calls to backend (Firebase Functions)
- Validates user session before token generation

### ✅ Automatic Token Refresh
- SDK handles token expiration automatically
- No manual token refresh needed
- Seamless user experience

### ✅ Secure Token Generation
- Tokens generated server-side only
- Uses Stream server SDK with API secret
- Tokens include proper claims (iat, user_id, etc.)

### ✅ Firebase Integration
- Works with Firebase Auth automatically
- Uses Firebase Functions for backend
- Automatic user creation/deletion via triggers

## Firebase Functions Setup

Your Firebase Functions automatically:
- **Create Stream users** when Firebase users are created (`createStreamUser`)
- **Delete Stream users** when Firebase users are deleted (`deleteStreamUser`)
- **Generate tokens** for authenticated users (`getStreamUserToken`)

## Configuration

Required environment variables in Firebase Functions:
- `STREAM_API_KEY` - Must match `Config.streamAPIKey` in iOS app
- `STREAM_API_SECRET` - Used to sign tokens
- `NAME_FIELD`, `EMAIL_FIELD`, `IMAGE_FIELD` (optional)

## Usage

The token provider is automatically used when:
- Initializing the Stream client
- Token expires during API calls
- SDK detects authentication issues

No manual intervention needed - it's all handled automatically!

## Benefits Over Previous Implementation

1. **Follows Official Pattern**: Based on Stream's documented best practices
2. **Cleaner Code**: Separated token provider into its own class
3. **Better Error Handling**: Proper error propagation
4. **Automatic Refresh**: SDK handles everything automatically
5. **Thread-Safe**: No manual token state management needed

## References

- [Stream iOS Token Documentation](https://getstream.io/activity-feeds/docs/ios/tokens-and-authentication/)
- Firebase Functions code: `functions/src/index.ts`
- Token Provider: `OraBeta/Utils/StreamTokenProvider.swift`





























