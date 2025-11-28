# Quick Pagination Test Checklist

## 🚀 Quick Test (5 minutes)

### Step 1: Enable Debug Overlay
1. Open `DiscoverFeedView.swift`
2. Find line with `// .overlay(PaginationDebugOverlay(viewModel: viewModel), alignment: .topLeading)`
3. Uncomment it (remove the `//`)
4. Run the app

### Step 2: Visual Verification
1. Navigate to Discover Feed
2. Look for debug overlay in top-left corner
3. Verify:
   - ✅ Posts count starts at 0, then updates to 20
   - ✅ Loading state shows "🔄 Initial" then "✅ Idle"
   - ✅ Has More shows "✅ Yes"

### Step 3: Test Pagination
1. Scroll down slowly
2. Watch the debug overlay
3. When you reach post #18-20:
   - Loading should change to "⏳ More"
   - Posts count should increase (20 → 40 → 60...)
   - Has More should remain "✅ Yes" (until end)

### Step 4: Check Console Logs
Open Xcode console and verify you see:
```
🔄 DiscoverFeedViewModel: Loading posts from discover feed
✅ DiscoverFeedViewModel: Loaded 20 posts from discover feed
   Has more: true

[Scroll to post #18]
🔄 DiscoverFeedViewModel: Loading more posts
   Current post count: 20
✅ DiscoverFeedViewModel: Loaded 20 more posts
   Total posts: 40
   Has more: true
```

### Step 5: Test Edge Cases
1. **Rapid Scrolling**: Scroll very fast - should see debounce message
2. **End of Feed**: Keep scrolling until no more posts - Has More should become "❌ No"
3. **Search Mode**: Enter search text - pagination should be disabled

## ✅ Success Criteria

- [ ] Initial 20 posts load correctly
- [ ] Scrolling triggers pagination at post #18-20
- [ ] New posts are appended (not replacing)
- [ ] Post count increases: 20 → 40 → 60...
- [ ] No duplicate posts
- [ ] Loading states update correctly
- [ ] Debouncing prevents rapid loads
- [ ] End of feed is detected correctly

## 🐛 If Something's Wrong

### Posts Not Loading
- Check console for errors
- Verify Firebase connection
- Check authentication state

### Pagination Not Triggering
- Verify `onItemAppear` is being called (add breakpoint)
- Check threshold calculation
- Verify `hasMore` is true

### Duplicate Posts
- Check cursor (lastDocument) is being saved
- Verify posts array isn't being reset

### Infinite Loading
- Check `hasMore` is being set to false at end
- Verify cursor is nil when no more posts

## 📊 Expected Console Output

```
🔄 DiscoverFeedViewModel: Loading posts from discover feed
   User ID: [your-user-id]
   Strategy: HybridStrategy
📌 DiscoverFeedViewModel: Posts array updated
   Total posts: 20
   Last document exists: true
✅ DiscoverFeedViewModel: Loaded 20 posts from discover feed
   Has more: true

[User scrolls to post #18]
🔄 DiscoverFeedViewModel: Loading more posts
   Current post count: 20
   Last document ID: [document-id]
   Page size: 20
📌 DiscoverFeedViewModel: Appended 20 posts
   Previous count: 20, New count: 40
✅ DiscoverFeedViewModel: Loaded 20 more posts
   Total posts: 40
   Has more: true
```






