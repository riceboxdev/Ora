//
//  DiscoverFeedView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth
import MasonryStack
import Kingfisher
import Foundation
import StretchyHeaderUI

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - DiscoverFeedView

struct DiscoverFeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: DiscoverFeedViewModel
    @State private var navigationPath = NavigationPath()
    @State private var selectedTopic: TrendingTopic?
    
    // MARK: - Initialization
    
    init() {
        // Create ViewModel with DIContainer services
        _viewModel = StateObject(wrappedValue: DiscoverFeedViewModel())
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationDestination(for: TrendingTopic.self) { topic in
                    TopicFeedView(topic: topic)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Image("oravectorcropped")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: ViewConstants.Toolbar.logoHeight)
                            .transition(.opacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .refreshable {
                    await handleRefresh()
                }
                .task {
                    await viewModel.loadInitialData()
                }
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            loadingView
        } else if viewModel.posts.isEmpty {
            emptyStateView
        } else {
            feedScrollView
                .ignoresSafeArea()
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack {
            Text("No posts to discover")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var feedScrollView: some View {
        ScrollView {
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(viewModel.featuredTopics) { topic in
                        FeaturedTopicCard(
                            topic: topic,
                            previewPosts: viewModel.topicPreviews[topic.id] ?? [],
                            navigationPath: $navigationPath
                        )
                        .frame(height: 300)
                    }
                }
            }
//                           FeaturedTopicsHero(
//                               topics: viewModel.featuredTopics,
//                               topicPreviews: viewModel.topicPreviews,
//                               navigationPath: $navigationPath
//                           )
                       

            LazyVStack(spacing: 0) {
                // Hero section with featured topics
//                if viewModel.isLoadingTrendingTopics || (!viewModel.trendingTopics.isEmpty && viewModel.featuredTopics.isEmpty) {
//                    // Show placeholder while loading
//                    FeaturedTopicsHeroPlaceholder()
//                        .transition(.opacity)
//                        .ignoresSafeArea()
//                } else if !viewModel.featuredTopics.isEmpty {
//                    // Show actual content when loaded
//                    FeaturedTopicsHero(
//                        topics: viewModel.featuredTopics,
//                        topicPreviews: viewModel.topicPreviews,
//                        navigationPath: $navigationPath
//                    )
//                    .transition(.opacity)
//                    .ignoresSafeArea()
//                }
                Divider()
                
                // User discovery row
                if viewModel.isLoadingRecommendedUsers && (viewModel.recommendedUsers.isEmpty && viewModel.suggestedUsers.isEmpty) {
                    SuggestedUsersRowPlaceholder()
                        .transition(.opacity)
                } else {
                    SuggestedUsersRow(
                        users: viewModel.recommendedUsers.isEmpty ? viewModel.suggestedUsers : viewModel.recommendedUsers,
                        profileService: viewModel.profileService
                    )
                    .transition(.opacity)
                }
                
                // Regular trending topics section (excluding featured ones)
                if viewModel.isLoadingTrendingTopics && viewModel.trendingTopics.isEmpty {
                    TrendingTopicsSectionPlaceholder()
                        .transition(.opacity)
                } else if !viewModel.trendingTopics.isEmpty {
                    TrendingTopicsSection(
                        viewModel: viewModel,
                        navigationPath: $navigationPath
                    )
                    .transition(.opacity)
                }
                
                PostGrid(
                    posts: $viewModel.posts,
                    onItemAppear: nil // Disable item-based pagination
                )
                
                // Reusable Pagination Footer
                PaginationFooter(viewModel: viewModel)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                // Reserved for additional scroll detection if needed
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.featuredTopics.count)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingTrendingTopics)
            .animation(.easeInOut(duration: 0.3), value: viewModel.recommendedUsers.count)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingRecommendedUsers)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Helper Methods
    
    private func handleRefresh() async {
        await viewModel.loadPosts()
        await viewModel.loadSuggestedUsers()
        await viewModel.loadRecommendedUsers()
        await viewModel.loadGlobalTrendingTopics()
        
        // Reload previews and reselect featured topics after topics are loaded
        if !viewModel.trendingTopics.isEmpty {
            await viewModel.loadTopicPreviews()
            viewModel.selectFeaturedTopics()
        }
    }
}

// MARK: - FeaturedTopicsHero

struct FeaturedTopicsHero: View {
    let topics: [TrendingTopic]
    let topicPreviews: [String: [Post]]
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(topics) { topic in
                    FeaturedTopicCard(
                        topic: topic,
                        previewPosts: topicPreviews[topic.id] ?? [],
                        navigationPath: $navigationPath
                    )
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
    }
}

// MARK: - FeaturedTopicCard

struct FeaturedTopicCard: View {
    let topic: TrendingTopic
    let previewPosts: [Post]
    let cardHeight: CGFloat = 300
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Button(action: {
            navigationPath.append(topic)
        }) {
            ZStack(alignment: .bottomLeading) {
                // Background image (first post)
                backgroundImage
                    .stretchy()
                
                // Gradient overlay for text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
//                .frame(height: cardHeight)
                .containerRelativeFrame(.horizontal)
                
                // Content - constrained to bottom
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    
                    // Topic header at bottom
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(topic.name)
                                .font(.creatoDisplayHeadline())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 8)
                            
                            if topic.growthRate > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                    Text("\(Int(topic.growthRate * 100))%")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        Text("\(topic.postCount) posts")
                            .font(.creatoDisplayCaption(.regular))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        // Subtle background for text area
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.black.opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
//                .frame(height: cardHeight)
                .containerRelativeFrame(.horizontal)
                
                // Overlay images in bottom corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        overlayImages
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
//                .frame(height: cardHeight)
                .containerRelativeFrame(.horizontal)
            }
//            .frame(height: cardHeight)
            .containerRelativeFrame(.horizontal)
//            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .containerRelativeFrame(.horizontal)
    }
    
    private var backgroundImage: some View {
        Group {
            if let firstPost = previewPosts.first {
                let imageUrlString = firstPost.thumbnailUrl ?? firstPost.imageUrl
                if let url = URL(string: imageUrlString) {
                    KFImage(url)
                        .placeholder {
                            // Fallback gradient if no image
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accent.opacity(0.8),
                                    Color.accent.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback gradient if URL is invalid
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accent.opacity(0.8),
                            Color.accent.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                // Fallback gradient if no posts
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accent.opacity(0.8),
                        Color.accent.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var overlayImages: some View {
        HStack(spacing: 4) {
            // Show second and third posts as overlay images
            let overlayPosts = Array(previewPosts.dropFirst().prefix(2))
            
            ForEach(overlayPosts, id: \.id) { post in
                Group {
                    let imageUrlString = post.thumbnailUrl ?? post.imageUrl
                    if let url = URL(string: imageUrlString) {
                        KFImage(url)
                            .placeholder {
                                Color.white.opacity(0.3)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.3)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
        }
    }
}

// MARK: - TrendingTopicsSection


extension View {
    func stretchy() -> some View {
        visualEffect { effect, geometry in
            let currentHeight = geometry.size.height
            let scrollOffset = geometry.frame(in: .scrollView).minY
            let positiveOffset = max(0, scrollOffset)
            
            let newHeight = currentHeight + positiveOffset
            let scaleFactor = newHeight / currentHeight
            
            return effect.scaleEffect(
                x: scaleFactor, y: scaleFactor,
                anchor: .bottom
            )
        }
    }
}

struct TrendingTopicsSection: View {
    @ObservedObject var viewModel: DiscoverFeedViewModel
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topicsScrollView
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var topicsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Show all topics except featured ones (they're in the hero section)
                let featuredTopicIds = Set(viewModel.featuredTopics.map { $0.id })
                let regularTopics = viewModel.trendingTopics.filter { !featuredTopicIds.contains($0.id) }
                
                ForEach(regularTopics) { topic in
                    TrendingTopicButton(
                        topic: topic,
                        navigationPath: $navigationPath
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}


// MARK: - TrendingTopicButton

struct TrendingTopicButton: View {
    let topic: TrendingTopic
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Button(action: {
            navigationPath.append(topic)
        }) {
            HStack(spacing: 4) {
                Text(topic.name)
                    .font(.subheadline)
                    .fontWeight(.regular)
                
                if topic.growthRate > 0 {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                }
                
                Text("(\(topic.postCount))")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - SuggestedUsersRow

struct SuggestedUsersRow: View {
    let users: [UserProfile]
    let profileService: ProfileServiceProtocol
    
    var body: some View {
        VStack {
            Text("Popular Users")
                .font(.creatoDisplayHeadline(.medium))
                .hLeading()
                .padding(.horizontal)
            if !users.isEmpty {
                usersScrollView
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var usersScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(users) { user in
                    SuggestedUserCard(
                        user: user,
                        profileService: profileService
                    )
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal)
    }
}

// MARK: - SuggestedUserCard

struct SuggestedUserCard: View {
    let user: UserProfile
    let profileService: ProfileServiceProtocol
    
    @State private var isFollowing: Bool = false
    @State private var isLoading: Bool = false
    @State private var currentUserId: String?
    
    // MARK: - Computed Properties
    
    private var canFollow: Bool {
        guard let currentUserId = currentUserId,
              let userId = user.id else {
            return false
        }
        return currentUserId != userId
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationLink(destination: {
            if let userId = user.id {
                OtherProfileView(userId: userId)
            }
        }) {
            VStack(spacing: 12) {
                profileImageView
                userInfoView
                
                if canFollow {
                    followButton
                }
            }
            .padding(.vertical, 12)
            .containerRelativeFrame(.horizontal, count: 3, spacing: 10)
            
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            currentUserId = Auth.auth().currentUser?.uid
            await loadFollowState()
        }
    }
    
    // MARK: - Subviews
    
    private var profileImageView: some View {
        Group {
            if let profilePhotoUrl = user.profilePhotoUrl,
               let url = URL(string: profilePhotoUrl),
               !profilePhotoUrl.isEmpty {
                KFImage(url)
                    .placeholder {
                        Image("defaultavatar")
                            .resizable()
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image("defaultavatar")
                    .resizable()
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var userInfoView: some View {
        VStack(spacing: 4) {
            Text(user.displayName ?? user.username)
                .font(.creatoDisplaySubheadline(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("@\(user.username)")
                .font(.creatoDisplayCaption(.regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 120)
    }
    
    private var followButton: some View {
        Button(action: {
            Task {
                await toggleFollow()
            }
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.creatoDisplayCaption(.medium))
                    }
                }
            }
            .foregroundColor(isFollowing ? .primary : .black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isFollowing
                    ? Color(UIColor.tertiarySystemFill)
                    : Color.ora,
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func loadFollowState() async {
        guard let userId = user.id,
              let currentUserId = currentUserId,
              userId != currentUserId else {
            return
        }
        
        do {
            isFollowing = try await profileService.isFollowing(followingId: userId)
        } catch {
            print("⚠️ SuggestedUserCard: Failed to load follow state: \(error.localizedDescription)")
        }
    }
    
    private func toggleFollow() async {
        guard let userId = user.id,
              let currentUserId = currentUserId,
              userId != currentUserId else {
            return
        }
        
        let wasFollowing = isFollowing
        
        isLoading = true
        isFollowing = !wasFollowing
        
        do {
            if wasFollowing {
                try await profileService.unfollowUser(followingId: userId)
            } else {
                try await profileService.followUser(followingId: userId)
                NotificationCenter.default.post(
                    name: Foundation.Notification.Name.feedShouldRefresh,
                    object: nil
                )
            }
        } catch {
            print("❌ SuggestedUserCard: Failed to toggle follow: \(error.localizedDescription)")
            isFollowing = wasFollowing
        }
        
        isLoading = false
    }
}

// MARK: - Placeholder Views

struct FeaturedTopicsHeroPlaceholder: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Show 2-3 placeholder cards to match typical featured topics count
                ForEach(0..<3, id: \.self) { _ in
                    FeaturedTopicCardPlaceholder()
                }
            }
        }
    }
}

struct FeaturedTopicCardPlaceholder: View {
    let height: CGFloat = 300
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background placeholder - matches 300x200 size
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: height)
            
            // Bottom gradient overlay placeholder
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.2)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
        }
        .containerRelativeFrame(.horizontal)
        .frame(height: 300)
    }
}

struct SuggestedUsersRowPlaceholder: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SuggestedUserCardPlaceholder()
                }
            }
        }
    }
}

struct SuggestedUserCardPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            // Profile image placeholder - matches 70x70 circle
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 70, height: 70)
            
            // User info placeholder - matches text area dimensions
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 80, height: 14)
            }
            .frame(width: 120, alignment: .center)
            
            // Follow button placeholder - matches button dimensions (capsule with padding)
            Capsule()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 70, height: 28)
        }
        .padding(12)
        .frame(width: 140, alignment: .center)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct TrendingTopicsSectionPlaceholder: View {
    private let widths: [CGFloat] = [70, 85, 60, 90, 75, 65, 80, 95]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { index in
                        TrendingTopicButtonPlaceholder(width: widths[index % widths.count])
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct TrendingTopicButtonPlaceholder: View {
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: width, height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.12))
                .frame(width: 35, height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(20)
    }
}

#Preview {
    DiscoverFeedView()
        .environmentObject(AuthViewModel())
        .environmentObject(DIContainer.shared)
        .previewAuthenticated()
}

