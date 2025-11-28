//
//  PostGrid.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import MasonryStack
import ColorKit

/// Represents an item in the grid - either a post or an ad
enum PostGridItem {
    case post(Post)
    case ad
    
    var id: String {
        switch self {
        case .post(let post):
            return post.id
        case .ad:
            return UUID().uuidString
        }
    }
}

/// A reusable component for displaying posts in a masonry grid layout
/// Used consistently across Home, Discover, Profile, and other views
struct PostGrid: View {
    @Binding var posts: [Post]
    let columns: Int
    let spacing: CGFloat
    let onItemAppear: ((Post) -> Void)?
    let queryID: String? // For Algolia click tracking (from search results)
    let adsEnabled: Bool // Whether ads are enabled for this instance
    
    @StateObject private var remoteConfigService = RemoteConfigService.shared
    @Namespace private var namespace
    
    // Ad insertion interval (show ad every N posts)
    // Can be overridden via parameter, or will use Remote Config value if available
    private let adInterval: Int?
    
    init(
        posts: Binding<[Post]>,
        columns: Int = 2,
        spacing: CGFloat = 5,
        onItemAppear: ((Post) -> Void)? = nil,
        queryID: String? = nil,
        adsEnabled: Bool = false,
        adInterval: Int? = nil
    ) {
        self._posts = posts
        self.columns = columns
        self.spacing = spacing
        self.onItemAppear = onItemAppear
        self.queryID = queryID
        self.adsEnabled = adsEnabled
        self.adInterval = adInterval
    }
    
    // Convenience initializer for non-binding usage
    init(
        posts: [Post],
        columns: Int = 2,
        spacing: CGFloat = 5,
        onItemAppear: ((Post) -> Void)? = nil,
        queryID: String? = nil,
        adsEnabled: Bool = false,
        adInterval: Int? = nil
    ) {
        self._posts = Binding.constant(posts)
        self.columns = columns
        self.spacing = spacing
        self.onItemAppear = onItemAppear
        self.queryID = queryID
        self.adsEnabled = adsEnabled
        self.adInterval = adInterval
    }
    
    /// Computed property to determine if ads should be shown
    /// Ads are shown only if:
    /// 1. This PostGrid instance has adsEnabled = true
    /// 2. Remote Config has ads enabled globally
    private var shouldShowAds: Bool {
        adsEnabled && remoteConfigService.areAdsEnabled
    }
    
    /// Gets the effective ad interval to use
    /// Priority: 1. Parameter override, 2. Remote Config, 3. Default (5)
    private var effectiveAdInterval: Int {
        // First check if explicitly set via parameter
        if let interval = adInterval {
            return max(1, interval) // Ensure at least 1
        }
        
        // Then use Remote Config value
        return max(1, remoteConfigService.adFrequency) // Ensure at least 1
    }
    
    /// Interleaves ads into the posts array at regular intervals
    private var gridItems: [PostGridItem] {
        guard shouldShowAds else {
            // No ads - just return posts
            return posts.map { .post($0) }
        }
        
        let interval = effectiveAdInterval
        var items: [PostGridItem] = []
        
        for (index, post) in posts.enumerated() {
            items.append(.post(post))
            
            // Insert ad after every N posts (but not after the last post)
            if (index + 1) % interval == 0 && index < posts.count - 1 {
                items.append(.ad)
            }
        }
        return items
    }
    
    var body: some View {
        MasonryVStack(columns: columns, spacing: spacing) {
            ForEach(Array(gridItems.enumerated()), id: \.element.id) { index, item in
                switch item {
                case .post(let post):
                    NavigationLink(
                        destination: PostDetailView(post: post, queryID: queryID)
                            .navigationTransition(.zoom(sourceID: post.id, in: namespace))
                    ) {
                        PostThumbnailView(post: post)
                            .matchedTransitionSource(id: post.id, in: namespace)
                            .onAppear {
                                Logger.info("📍 PostGrid: Post appeared - index: \(index), postId: \(post.id), total: \(posts.count)", service: "PostGrid")
                                // Call the onItemAppear callback if provided
                                if let callback = onItemAppear {
                                    Logger.info("✅ PostGrid: Calling onItemAppear callback", service: "PostGrid")
                                    callback(post)
                                } else {
                                    Logger.warning("⚠️ PostGrid: No onItemAppear callback provided!", service: "PostGrid")
                                }
                            }
                    }
                    
                case .ad:
                    AdView()
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(spacing)
        .transition(.opacity)
        .animation(.smooth, value: posts.map { $0.id })
    }
    
   
}

struct PostThumbnailView: View {
    let post: Post
    let cornerRadius: CGFloat = 20
    
    @State private var isLiked: Bool = false
    @State private var isLoadingLikedStatus: Bool = false
    private let engagementService = EngagementService()
    
    init(post: Post) {
        self.post = post
        // Ensure logging is enabled for thumbnail views
        LoggingControl.enable("PostThumbnailView")
    }
    
    // Cached URL to avoid repeated URL(string:) calls
    // Use effectiveThumbnailUrl which generates Cloudflare transformation URL if needed
    private var imageURL: URL? {
        let urlString = post.effectiveThumbnailUrl
        guard !urlString.isEmpty else {
            return nil
        }
        guard let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
    
    // Computed aspect ratio with fallback
    private var aspectRatio: CGFloat? {
        if let ratio = post.aspectRatio {
            return CGFloat(ratio)
        }
        return nil
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CachedImageView(
                url: imageURL,
                aspectRatio: aspectRatio,
                downsamplingSize: CGSize(width: 800, height: 800),
                contentMode: .fit
            )
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Red heart icon overlay in bottom right corner (only if user has liked)
            if isLiked {
                Image("heart.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
        .task {
            await checkLikedStatus()
        }
    }
    
    private func checkLikedStatus() async {
        guard !isLoadingLikedStatus else { return }
        isLoadingLikedStatus = true
        
        do {
            let (liked, _) = try await engagementService.hasLiked(postId: post.id)
            isLiked = liked
        } catch {
            // Silently fail - don't show heart if we can't check status
            isLiked = false
        }
        
        isLoadingLikedStatus = false
    }
    
}

struct BoardsGrid: View {
    let boards: [Board]
    
    
    @Namespace private var namespace
    let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 100)),
            GridItem(.adaptive(minimum: 100))
    ]
    
    init(
        boards: [Board]
    ) {
        self.boards = boards
    }
    
    var body: some View {
        MasonryVStack(columns: 2, spacing: 5) {
            ForEach(boards) { board in
                NavigationLink(
                    destination: BoardDetailView(board: board)
                        .navigationTransition(.zoom(sourceID: board.id, in: namespace))
                ) {
                    BoardThumbnailView(board: board)
                        .matchedTransitionSource(id: board.id, in: namespace)
                }
            }
        }
        .padding(5)
        .transition(.opacity)
        .animation(.smooth, value: boards)
    }
    
   
}

struct BoardThumbnailView: View {
    let board: Board
    
    private var imageURL: URL? {
        let urlString = board.coverImageUrl ?? ""
        guard !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    private var countText: String {
        board.postCount == 1 ? "1 post" : "\(board.postCount) posts"
    }
    
    @State private var color: Color = .clear
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CachedImageLoader(
                url: imageURL,
                downsamplingSize: CGSize(width: 800, height: 800),
                onImageLoaded: { image in
                    // This closure is called when the image loads
                    // You can use the image here in your parent view
                    if let image = image {
                        let avgcolor = try? image.averageColor()
                        self.color = Color(avgcolor ?? .clear)
                        // Do something with the image
                    }
                }
            ) { image, isLoading, hasError in
                // Build your custom view based on the states
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fit)
                        
                } else if hasError {
                    Text("Error loading image")
                } else if isLoading {
                    ProgressView()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .aspectRatio(9/16, contentMode: .fit)
                }
            }
        LinearGradient(
            colors: [
                .clear,
                color
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .aspectRatio(9/16, contentMode: .fit)
            
            VStack {
                Text(board.title)
                    .font(.creatoDisplayTitle())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(countText)
                    .font(.creatoDisplayCaption())
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .aspectRatio(9/16, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    ScrollView {
        PostGrid(
            posts: [
                Post(activityId: "1", userId: "user1", imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762805253/users/qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1/thumbnails/dyx5218izcpixy4z2muu.jpg", createdAt: Date()),
                Post(activityId: "2", userId: "user1", imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762551147/users/qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1/thumbnails/jtyqwd1styriaietmkoh.jpg", createdAt: Date()),
                Post(activityId: "3", userId: "user1", imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762550961/users/ChXrUkIGqsS1TMVi6avPKAhIlxn1/ahtif0rayebfwbf7auj4.jpg", createdAt: Date())
            ]
        )
    }
}

#Preview {
    NavigationStack {
        VStack {
            BoardThumbnailView(
                board: Board(id: UUID().uuidString,
                             title: "Homeee",
                             description: "Home decor",
                             coverImageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762805434/users/qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1/m9khlosdnjthi9shiwnq.jpg",
                             isPrivate: false,
                             userId: "xLX0DReWAPQad0Hl6H1hp90fnjA3",
                             postCount: 1,
                             createdAt: Date.now
                            )
            )
        }
    }
}

