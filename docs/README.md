# OraBeta Documentation

This directory contains organized documentation for the OraBeta project.

## Directory Structure

### 📁 [setup/](setup/)
Setup and configuration guides for various services and integrations:
- **SETUP_GUIDE.md** - Main setup guide for the entire project
- **ALGOLIA_EVENTS_SETUP.md** - Algolia Events API integration
- **FIRESTORE_RULES_SETUP.md** - Firestore security rules configuration
- **SETUP_STREAM_SECRET.md** - Stream API secret configuration
- **STREAM_SECRET_SETUP_COMPLETE.md** - Stream setup completion notes
- **UPDATE_STREAM_API_KEY.md** - Stream API key update instructions

### 📁 [deployment/](deployment/)
Deployment instructions for Firebase Functions and infrastructure:
- **DEPLOYMENT.md** - Main deployment guide (consolidated)
- **DEPLOY_CLOUDINARY_FUNCTION.md** - Cloudinary function deployment
- **FIX_CLOUDINARY_DEPLOYMENT.md** - Cloudinary deployment fixes
- **FIX_CLOUDINARY_FUNCTION.md** - Cloudinary function troubleshooting

### 📁 [testing/](testing/)
Testing guides and procedures:
- **LOCAL_TESTING.md** - Local Firebase Functions testing with emulator
- **FUNCTION_TESTING.md** - Function testing procedures
- **BUILD_AND_TEST.md** - Build and test instructions
- **PAGINATION_TESTING_GUIDE.md** - Pagination testing guide
- **TESTING_SUMMARY.md** - Testing summary and checklist

### 📁 [architecture/](architecture/)
Architecture documentation and data structures:
- **POST_DATA_STRUCTURE.md** - Post data structure in Firestore
- **POST_STORAGE_AND_EDITING.md** - Post storage and editing implementation
- **IMAGE_DIMENSIONS_USAGE.md** - Image dimensions usage guide
- **LOGGING_CONTROL_GUIDE.md** - Logging control and configuration
- **TOKEN_PROVIDER_IMPLEMENTATION.md** - Token provider implementation details
- **UNUSED_FUNCTIONS.md** - Analysis of unused Firebase Functions

### 📁 [archive/](archive/)
Historical documentation, completed migrations, and outdated guides:
- Migration summaries (Board, Firebase Following/Liking, Stream v2)
- Completed fix summaries (Token fix, etc.)
- Outdated debug guides (Pagination, Stream auth, etc.)
- Implementation summaries from past development sessions

## Quick Links

### Getting Started
1. Read [SETUP_GUIDE.md](setup/SETUP_GUIDE.md) for initial project setup
2. Configure services using guides in [setup/](setup/)
3. Deploy using [DEPLOYMENT.md](deployment/DEPLOYMENT.md)

### Development
- Test locally: [LOCAL_TESTING.md](testing/LOCAL_TESTING.md)
- Understand data structures: [architecture/](architecture/)
- Review testing procedures: [testing/](testing/)

### Troubleshooting
- Check deployment issues: [deployment/](deployment/)
- Review architecture docs: [architecture/](architecture/)
- Historical fixes: [archive/](archive/)

## Notes

- **Archive folder**: Contains historical documentation that may be outdated but kept for reference
- **Consolidated guides**: Duplicate deployment instructions have been merged into `deployment/DEPLOYMENT.md`
- **Active documentation**: Focus on `setup/`, `deployment/`, `testing/`, and `architecture/` for current information

