# Pagination System Testing Guide

This guide helps you verify that the pagination system in DiscoverFeedView is working correctly.

## 🧪 Testing Methods

### 1. Manual Testing with Console Logs

The system already has extensive logging. Watch the Xcode console while testing:

#### Initial Load Test
1. Open the Discover Feed
2. Watch console for:
   ```
   🔄 DiscoverFeedViewModel: Loading posts from discover feed
   ✅ DiscoverFeedViewModel: Loaded 20 posts from discover feed
   Has more: true
   ```

#### Pagination Trigger Test
1. Scroll down slowly through the feed
2. When you reach post #18, #19, or #20 (last 3), watch for:
   ```
   🔄 DiscoverFeedViewModel: Loading more posts
   Current post count: 20
   ✅ DiscoverFeedViewModel: Loaded 20 more posts
   Total posts: 40
   Has more: true
   ```

#### End of Feed Test
1. Keep scrolling until you reach the end
2. Should see:
   ```
   ⚠️ DiscoverFeedViewModel: Cannot load more - no lastDocument
   ```
   OR
   ```
   No posts returned - setting hasMore to false
   ```

### 2. Visual Debug Overlay

Add a debug overlay to see pagination state in real-time.

### 3. Unit Tests

Test the pagination logic in isolation.

### 4. Performance Testing

Verify debouncing and prevent duplicate loads.

---

## ✅ What to Verify

### Initial Load
- [ ] First 20 posts load correctly
- [ ] `isLoading` becomes `false` after load
- [ ] `hasMore` is `true` if more posts exist
- [ ] `lastDocument` is set (check console logs)

### Pagination Trigger
- [ ] Scrolling to post #18-20 triggers load
- [ ] `isLoadingMore` becomes `true` during load
- [ ] New posts are appended (not replacing)
- [ ] Post order remains stable (no reordering)
- [ ] `hasMore` updates correctly

### Debouncing
- [ ] Rapid scrolling doesn't trigger multiple loads
- [ ] At least 1 second between load requests
- [ ] Console shows: "⏸️ Debouncing load more request"

### Edge Cases
- [ ] End of feed: `hasMore` becomes `false`
- [ ] No duplicate posts in the array
- [ ] Loading state prevents concurrent loads
- [ ] Search mode disables pagination

### State Management
- [ ] `onItemAppear` guards work correctly
- [ ] Threshold calculation is accurate
- [ ] Cursor (lastDocument) is preserved between loads

---

## 🐛 Common Issues to Watch For

1. **Infinite Loading Loop**
   - Check if `hasMore` is being set incorrectly
   - Verify cursor is being saved

2. **Posts Not Appearing**
   - Check if `onItemAppear` is being called
   - Verify threshold calculation

3. **Duplicate Posts**
   - Check if cursor is working correctly
   - Verify posts array isn't being reset

4. **UI Flickering**
   - Should use atomic updates (entire array replacement)
   - Check if re-ranking is disabled during pagination






