---
description: Repository Information Overview
alwaysApply: true
---

# OraBeta Repository Information

## Summary
OraBeta is a multi-project visual discovery and collection iOS app ecosystem built with SwiftUI, Vue.js, Node.js, and Firebase. The repository includes a native iOS application, web-based admin dashboard, backend services, Firebase Cloud Functions, and reusable Swift packages.

## Repository Structure

**Main Components:**
- **OraBeta/** - iOS app source code (SwiftUI)
- **admin-dashboard/** - Vue.js admin dashboard web app
- **server/** - Express.js backend API
- **functions/** - Firebase Cloud Functions (TypeScript)
- **Swift Packages** - 6 reusable packages (FeatureFlags, OraLogging, PageableKit, FirebaseUtils, ImageUtils, OraBetaAdminSDK)
- **docs/** - Project documentation (setup, deployment, testing, architecture)
- **Configuration Files** - Firebase, Netlify, Vercel deployment configs

---

## iOS App (OraBeta)

**Platform:** iOS 15+ (SwiftUI)  
**Build System:** Xcode (Ora.xcodeproj)  
**Language:** Swift (Swift 5.9+)

### Main Entry Point
- **OraBetaApp.swift** - Main app entry point with Firebase initialization, remote config setup, and route management
- **ContentView.swift** - Primary navigation container
- Architecture: DIContainer for dependency injection, MVVM pattern

### Key Frameworks & Dependencies
- **SwiftUI** - UI framework
- **Firebase** - Authentication, Firestore, Remote Config, Cloud Functions
- **FirebaseCore**, **FirebaseAuth**, **FirebaseFirestore**, **FirebaseRemoteConfig**
- **Kingfisher** - Image caching and management
- **Stream Activity Feeds** - Social feed infrastructure
- **Cloudinary** - Image upload/storage

### Project Structure
- **Models/** - Data models and services
- **ViewModels/** - State management (AuthViewModel, RemoteConfigService)
- **Views/** - SwiftUI components
- **Services/** - Business logic and API integrations
- **Utils/** - Configuration and utilities

### Testing
- **OraBetaTests/** - Unit tests (4 test files: Pagination, Onboarding, StoryPackage, UploadQueue)
- **OraBetaUITests/** - UI automation tests
- Build command: `xcodebuild test`

---

## Swift Packages (6 Packages)

All packages use **Swift 5.9+** and support **iOS 15+** (and macOS 12+).

### 1. **FeatureFlags** Package
Protocol-based feature flag management with Firebase Remote Config support. Provides observable service for reactive updates.
- **Test Target:** FeatureFlagsTests
- **Platforms:** iOS 15+, macOS 12+

### 2. **OraLogging** Package
Centralized logging system with configurable service-based logging levels.
- **Test Target:** OraLoggingTests
- **Platforms:** iOS 15+, macOS 12+

### 3. **PageableKit** Package
Pagination and infinite scroll utilities for data management.
- **Test Target:** PageableKitTests
- **Platforms:** iOS 15+, macOS 12+

### 4. **FirebaseUtils** Package
Firebase-related utilities and extensions.
- **Platforms:** iOS 15+, macOS 12+

### 5. **ImageUtils** Package
Image processing and optimization utilities.
- **Test Target:** ImageUtilsTests
- **Platforms:** iOS 15+, macOS 12+

### 6. **OraBetaAdminSDK** Package
Admin functionality SDK for the app.
- **API Reference:** API_REFERENCE.md
- **Test Target:** OraBetaAdminSDKTests
- **Platforms:** iOS 15+, macOS 12+

---

## Admin Dashboard (Web App)

**Framework:** Vue 3 + Vite  
**Build System:** Vite  
**Package Manager:** npm  
**Node Version:** 16+ (recommended)

### Main Configuration Files
- **vite.config.js** - Vite build configuration with Vue plugin, API proxy, chunk optimization
- **tailwind.config.js** - Tailwind CSS configuration
- **postcss.config.js** - PostCSS configuration

### Key Dependencies
- **@nuxtjs/tailwindcss** - Tailwind CSS integration
- **@headlessui/vue** - Headless UI components
- **@heroicons/vue** - Icon library
- **Vue Router** - Client-side routing
- **Pinia** - State management
- **Chart.js + vue-chartjs** - Analytics and charts
- **Firebase SDK** - Firebase authentication and Firestore
- **Axios** - HTTP client
- **bcryptjs** - Password hashing
- **jsonwebtoken** - JWT auth

### Build & Scripts
```bash
npm install
npm run dev        # Development server (port 5173)
npm run build      # Build for production
npm run preview    # Preview production build
```

### Deployment Targets
- **Vercel** - Primary deployment (vercel.json configured)
- **Netlify** - Secondary deployment (netlify.toml configured)

### Environment Variables (.env.example)
- `VITE_API_URL` - Backend API URL
- `VITE_FIREBASE_*` - Firebase credentials (API key, auth domain, project ID, etc.)
- `VITE_APP_TITLE` - App title

---

## Backend API (Express.js Server)

**Runtime:** Node.js (16+ recommended)  
**Framework:** Express.js  
**Package Manager:** npm

### Main Entry Point
- **server/index.js** - Express app initialization with routes and middleware

### Key Dependencies
- **express** - Web framework
- **cors** - CORS middleware
- **dotenv** - Environment variable management
- **express-rate-limit** - Rate limiting
- **express-validator** - Input validation
- **mongoose** - MongoDB ODM
- **firebase-admin** - Firebase admin SDK
- **multer** - File upload handling
- **bcryptjs** - Password hashing
- **jsonwebtoken** - JWT authentication

### Route Modules (src/routes/)
- `auth.js` - Authentication routes
- `admin.js` - Admin management routes
- `reports.js` - Reporting routes
- `interests.js` - User interests routes
- `classification.js` - Content classification routes

### Configuration
- **src/config/database.js** - MongoDB connection
- **src/config/firebase.js** - Firebase admin initialization
- **.env.example** - Environment template

---

## Firebase Cloud Functions

**Runtime:** Node.js 20  
**Language:** TypeScript  
**Build Tool:** TypeScript Compiler (tsc)  
**Framework:** Firebase Functions

### Main Entry Points
- **functions/src/index.ts** - Primary functions
- **functions/src/notifications.ts** - Notification handling

### Key Dependencies
- **firebase-functions** - Firebase Functions SDK
- **firebase-admin** - Firebase admin SDK
- **cloudinary** - Image processing
- **getstream** - Stream Activity Feeds integration

### Build & Deployment Scripts
```bash
npm run build              # Compile TypeScript
npm run serve             # Local emulation
npm run deploy            # Deploy to Firebase
npm run logs              # View function logs
npm run shell             # Interactive shell
```

### Configuration
- **tsconfig.json** - Compiles src/index.ts and src/notifications.ts, targets ES2020, outputs to lib/

---

## Root Configuration Files

### Firebase Configuration
- **firebase.json** - Firebase project settings and function deployment config
- **firestore.rules** - Firestore security rules
- **firestore.indexes.json** - Firestore composite indexes

### Deployment
- **vercel.json** - Vercel deployment config for admin dashboard
- **netlify.toml** - Netlify configuration for dashboard and functions

### Environment Files
- **.env.example** - Root environment template
- **.env.local.example** - Local development template
- **.env.netlify** - Netlify-specific environment variables
- **.env.production** - Production environment variables
- Various `.env.*` files for different deployment phases

### Root Scripts (package.json)
```bash
npm run install:all    # Install dependencies across all projects
npm run dev:backend    # Start backend development server
npm run dev:dashboard  # Start dashboard development server
npm run build          # Build admin dashboard
```

---

## Testing & Validation

### iOS Testing
- **Unit Tests:** OraBetaTests/ (Swift XCTest)
- **UI Tests:** OraBetaUITests/ (Swift XCTestDynamicOverlay)
- **Swift Package Tests:** Each package has dedicated test targets

### Dashboard Testing
- No dedicated test framework found in configuration
- Manual testing via `npm run dev` and `npm run preview`

### Backend/Functions Testing
- No explicit test framework configuration found

---

## Development Workflow

1. **iOS Development:** Open `Ora.xcodeproj` in Xcode, configure Firebase
2. **Dashboard Development:** `cd admin-dashboard && npm install && npm run dev`
3. **Backend Development:** `cd server && npm install && npm run dev`
4. **Firebase Functions:** `cd functions && npm run serve`
5. **Deployment:**
   - Dashboard → Vercel/Netlify
   - Functions → Firebase CLI (`firebase deploy --only functions`)
   - iOS → Xcode build and App Store distribution
