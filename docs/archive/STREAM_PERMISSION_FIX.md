# Stream Permission Error Fix

## Problem
Getting 403 error: "User does not have permission to add activities to feeds: user:{userId}"

This error occurs even when trying to post to the user's own feed, which suggests a token permissions issue.

## Solution

The issue is likely in the Stream Dashboard configuration. The Firebase Extension generates tokens, but the permissions need to be configured in Stream Dashboard.

### Step 1: Check Stream Dashboard Token Permissions

1. Go to https://dashboard.getstream.io/
2. Select your app (App ID: `1442982`)
3. Navigate to **Settings** → **Tokens** or **Authentication**
4. Check the token permissions for user tokens

### Step 2: Verify Feed Group Permissions

1. In Stream Dashboard, go to **Feeds** section
2. Check the `user` feed group permissions
3. Ensure it allows users to write to their own feed:
   - Feed group: `user`
   - Default visibility: Should allow users to write to their own feed
   - Permissions: Users should have write access to `user:{userId}` feeds

### Step 3: Check Firebase Extension Configuration

The Firebase Extension (`ext-auth-activity-feeds`) should be configured with:
- `STREAM_API_KEY`: `qyfy876f96h9`
- `STREAM_API_SECRET`: `eeem8bttegc8hxf9armqjwrg6azqjbchuafadcr3y9xe47u5tek93paxz6hvu3d5`

### Step 4: Verify Token Generation

The Firebase Extension should generate tokens with permissions to:
- Read from user feeds
- Write to own user feed (`user:{userId}`)
- Read from timeline, foryou, discover feeds

### Step 5: Test Token Permissions

You can test if the token has the right permissions by checking the Stream Dashboard logs or by examining the token payload (JWT).

## Alternative: Use Server-Side Posting Only

If you can't fix the token permissions, you can use server-side posting entirely:

1. Client uploads wallpaper to Cloudinary
2. Client calls Firebase Function `createWallpaperActivity`
3. Function uses server-side credentials to post to Stream
4. Function aggregates to other feeds

This approach bypasses client-side token permission issues entirely.

## Current Code Status

The code is already set up to:
1. ✅ Only post to user's own feed from client
2. ✅ Call server-side aggregation function after posting
3. ✅ Handle errors gracefully (activity stays in user feed even if aggregation fails)

The remaining issue is the token permissions configuration in Stream Dashboard.

























