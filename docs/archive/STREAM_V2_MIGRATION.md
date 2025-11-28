# Migrating to Stream Feeds v2

## Current Situation
- Currently using Stream Feeds v3 beta (`stream-feeds-swift @ 0.4.0`)
- v3 is unstable with incomplete iOS SDK
- Need to switch to stable v2

## Stream v2 SDK Options

### Option 1: Stream v2 REST API (Recommended)
Use the well-documented Stream v2 REST API directly:
- Base URL: `https://api.stream-io-api.com/api/v1.0/`
- Works with all the endpoints we need
- No dependency issues
- Fully documented: https://getstream.io/activity-feeds/docs/ios-swift/

## Recommended Approach
Use Stream v2 REST API for now since:
1. It's stable and well-documented
2. No dependency conflicts
3. We already have most of the code written
4. Can migrate to native SDK later if needed

## Next Steps
1. Remove v3 SPM packages from Xcode
2. Implement v2 REST API in StreamService.swift
3. Use proper v2 API endpoints and authentication

