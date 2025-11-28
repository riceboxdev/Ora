# OraBeta

A visual discovery and collection iOS app built with SwiftUI, Firebase, Stream Activity Feeds, and Cloudinary.

## Documentation

All project documentation has been organized in the [`docs/`](docs/) directory:

- **[Setup Guides](docs/setup/)** - Configuration and setup instructions
- **[Deployment](docs/deployment/)** - Deployment procedures for Firebase Functions
- **[Testing](docs/testing/)** - Testing guides and procedures
- **[Architecture](docs/architecture/)** - Data structures and implementation details
- **[Archive](docs/archive/)** - Historical documentation and completed migrations

### Quick Start

1. Read the [Setup Guide](docs/setup/SETUP_GUIDE.md) for initial configuration
2. Review [Deployment Guide](docs/deployment/DEPLOYMENT.md) for deploying functions
3. Check [Local Testing](docs/testing/LOCAL_TESTING.md) for development workflow

For detailed documentation, see [docs/README.md](docs/README.md).

## Project Structure

```
OraBeta/
├── OraBeta/              # iOS app source code
│   ├── Models/          # Data models and services
│   ├── ViewModels/      # View models for state management
│   ├── Views/           # SwiftUI views
│   └── Utils/           # Utilities and configuration
├── functions/           # Firebase Cloud Functions
│   ├── src/            # TypeScript source
│   └── lib/            # Compiled JavaScript
└── docs/               # Project documentation
```

## Technologies

- **SwiftUI** - iOS app framework
- **Firebase** - Authentication, Firestore, Cloud Functions
- **Stream Activity Feeds** - Social feed infrastructure
- **Cloudinary** - Image upload and storage
- **Algolia** - Search and personalization (optional)

## Getting Started

See the [Setup Guide](docs/setup/SETUP_GUIDE.md) for detailed setup instructions.

