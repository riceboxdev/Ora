# Local Firebase Functions Testing Guide

This guide shows you how to test your Firebase Functions locally without deploying them.

## Prerequisites

1. **Firebase CLI** installed globally:
   ```bash
   npm install -g firebase-tools
   ```

2. **Java 11+** installed (required for emulators):
   - Check: `java -version`
   - Install if needed: https://www.java.com/download/

3. **Firebase project initialized**:
   ```bash
   firebase login
   firebase use --add  # Select your project
   ```

## Step 1: Start the Firebase Emulator Suite

From the project root directory:

```bash
cd functions
npm install  # Make sure dependencies are installed
npm run build  # Compile TypeScript
cd ..
firebase emulators:start
```

Or use the convenience script:
```bash
cd functions
npm run serve
```

This will start:
- **Functions Emulator** on `http://localhost:5001`
- **Firebase Emulator UI** on `http://localhost:4000`
- **Auth Emulator** on `http://localhost:9099` (if configured)
- **Firestore Emulator** on `http://localhost:8080` (if configured)

## Step 2: Configure Your Swift App for Local Testing

### Option A: Using Environment Variable (Recommended)

1. In Xcode, go to your app scheme:
   - Click on your scheme name (next to the device selector)
   - Select "Edit Scheme..."
   - Select "Run" → "Arguments"
   - Under "Environment Variables", add:
     - **Name:** `USE_LOCAL_FUNCTIONS`
     - **Value:** `true`
   - Click "Close"

2. The app will automatically connect to the local emulator when running in DEBUG mode.

### Option B: Using Command Line Arguments

When running from terminal:
```bash
USE_LOCAL_FUNCTIONS=true /path/to/your/app
```

### Option C: Manual Configuration (for testing)

You can temporarily modify `FunctionsConfig.swift` to always use the emulator in debug builds by changing:

```swift
private static let useLocalEmulator = true  // Force enable
```

## Step 3: Authenticate with Local Emulator

The local emulator runs with **mock authentication**. You have a few options:

### Option A: Use Emulator Auth UI

1. Go to `http://localhost:4000` (Emulator UI)
2. Click on "Authentication"
3. Add test users manually

### Option B: Use Firebase Auth Emulator (Recommended)

1. Make sure Auth emulator is running (configured in `firebase.json`)
2. Your app will automatically use the Auth emulator when Functions emulator is connected
3. Sign up/sign in will work normally, but users are stored locally

### Option C: Use Production Auth with Local Functions

If you want to test with real users but local functions:

1. Comment out the emulator connection in `FunctionsConfig.swift` for Auth:
   ```swift
   // Don't connect Auth to emulator, only Functions
   ```
2. But keep Functions emulator connection enabled

**Note:** The current setup connects both Auth and Functions to emulators when `USE_LOCAL_FUNCTIONS=true`.

## Step 4: Set Up Environment Variables for Functions

The local emulator needs access to your environment variables. Create a `.env` file in the `functions` directory:

```bash
cd functions
touch .env
```

Add your environment variables (for local testing, you can use test values):
```env
STREAM_API_KEY=qyfy876f96h9
STREAM_API_SECRET=eeem8bttegc8hxf9armqjwrg6azqjbchuafadcr3y9xe47u5tek93paxz6hvu3d5
CLOUDINARY_CLOUD_NAME=ddlpzt0qn
CLOUDINARY_API_KEY=your_api_key_here
CLOUDINARY_API_SECRET=your_api_secret_here
```

**Important:** For security, add `.env` to `.gitignore`:
```bash
echo ".env" >> functions/.gitignore
```

The emulator will automatically load environment variables from:
1. `.env` file in `functions/` directory
2. `firebase functions:config:get` values (if using legacy config)
3. Or use `firebase functions:config:set` to set them for emulator

## Step 5: Test Your Functions

### Using the Emulator UI

1. Open `http://localhost:4000` in your browser
2. Navigate to "Functions" tab
3. You'll see all your functions listed
4. Click on a function to test it
5. Enter test data and click "Call Function"

### Using Your Swift App

1. Make sure emulator is running (`firebase emulators:start`)
2. Set `USE_LOCAL_FUNCTIONS=true` in your Xcode scheme
3. Run your app
4. All function calls will go to the local emulator
5. Check the terminal where emulator is running for logs

### Using curl (for quick testing)

```bash
# Test createPost function
curl -X POST http://localhost:5001/your-project-id/us-central1/createPost \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "imageUrl": "https://example.com/image.jpg",
      "caption": "Test post"
    }
  }'
```

### Using Firebase CLI

```bash
# Test a callable function
firebase functions:shell

# Then in the shell:
createPost({imageUrl: "https://example.com/image.jpg", caption: "Test"})
```

## Step 6: View Logs

### Real-time Logs
Watch the terminal where you ran `firebase emulators:start` - all function logs appear there.

### Emulator UI Logs
1. Go to `http://localhost:4000`
2. Click on "Logs" tab
3. See all function invocations and their logs

### Function-specific Logs
```bash
# View logs for a specific function
firebase functions:log --only createPost
```

## Common Issues & Solutions

### Issue: "Connection refused" or "Cannot connect to emulator"
**Solution:**
- Make sure emulator is running: `firebase emulators:start`
- Check the port is correct (default: 5001)
- Verify `USE_LOCAL_FUNCTIONS=true` is set in your scheme

### Issue: "Authentication failed" or "User not authenticated"
**Solution:**
- Make sure Auth emulator is running
- Sign in through your app (users are stored locally)
- Or configure to use production Auth (see Step 3, Option C)

### Issue: "Environment variable not found"
**Solution:**
- Create `.env` file in `functions/` directory
- Add required environment variables
- Restart the emulator

### Issue: "Function not found"
**Solution:**
- Make sure you've built the functions: `cd functions && npm run build`
- Check that the function name matches exactly
- Restart the emulator

### Issue: Functions work locally but fail when deployed
**Solution:**
- Check environment variables are set in Firebase:
  ```bash
  firebase functions:config:get
  ```
- Make sure all dependencies are in `package.json`
- Check that the function code is the same locally and deployed

## Testing the Stream Feed Issue Locally

To debug the Stream feed group issue locally:

1. **Start the emulator:**
   ```bash
   firebase emulators:start
   ```

2. **Set environment variables** in `functions/.env`:
   ```env
   STREAM_API_KEY=qyfy876f96h9
   STREAM_API_SECRET=eeem8bttegc8hxf9armqjwrg6azqjbchuafadcr3y9xe47u5tek93paxz6hvu3d5
   ```

3. **Enable local functions in Xcode:**
   - Add `USE_LOCAL_FUNCTIONS=true` to your scheme's environment variables

4. **Run your app and try creating a post**

5. **Check the emulator logs** - you'll see the full Stream API error response:
   ```
   Stream API Error Details: {...}
   HTTP Status Code: 404
   Stream Error Object: {"code": 6, "detail": "..."}
   ```

6. **Test using the test function:**
   - Call `testStreamFeeds` from your app
   - Check the detailed test results in the logs

## Hot Reloading (Development)

The emulator supports hot reloading! When you make changes to your function code:

1. Rebuild: `cd functions && npm run build`
2. The emulator will automatically reload
3. No need to restart the emulator

For faster development, you can use `tsc --watch`:
```bash
cd functions
tsc --watch
```

Then in another terminal:
```bash
firebase emulators:start --only functions
```

## Stopping the Emulator

Press `Ctrl+C` in the terminal where the emulator is running, or:
```bash
# Kill all emulator processes
pkill -f firebase-emulator
```

## Next Steps

- **Test your functions locally** before deploying
- **Use the enhanced error logging** to debug the Stream feed issue
- **Check the test results** from `testStreamFeeds` function
- **Deploy when ready:** `firebase deploy --only functions`

## Additional Resources

- [Firebase Emulator Suite Documentation](https://firebase.google.com/docs/emulator-suite)
- [Local Functions Testing](https://firebase.google.com/docs/functions/local-emulator)
- [Emulator UI](https://firebase.google.com/docs/emulator-suite/ui/overview)

