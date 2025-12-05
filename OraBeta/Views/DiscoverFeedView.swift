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
import Combine
import Toasts

// MARK: - Stretchy Header Configuration

private enum StretchyHeaderConfig {
    static let baseHeight: CGFloat = 300
    static let maxStretch: CGFloat = 150 // Maximum additional stretch when pulling down
}

// MARK: - DiscoverFeedView

struct DiscoverFeedView: View {
    @Environment(\.safeAreaInsets) var safeArea
    @EnvironmentObject var container: DIContainer
    @StateObject var viewModel: DiscoverFeedViewModel
    
    @State private var navigationPath = NavigationPath()
    @State private var showProfile = false
    @State private var profileUserId: String?
    @State private var showRefreshToast = false
    @Environment(\.presentToast) var presentToast
    @State private var selectedInterest: TrendingInterest?
    
    // MARK: - Initialization
    
    init() {
        // Create ViewModel with DIContainer services
        _viewModel = StateObject(wrappedValue: DiscoverFeedViewModel(container: DIContainer.shared))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationDestination(for: TrendingInterest.self) { interest in
                    InterestFeedView(interest: interest)
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
        PullEffectScrollView(
            actionTopPadding: safeArea.top,
            leadingAction: .init(symbol: "", action: {  }),
            centerAction: .init(symbol: "refresh.icon", action: {
                Task {
                    await handleRefresh()
                }
            }),
            trailingAction: .init(symbol: "", action: {  })
        ) {
            LazyVStack(spacing: 0) {
                // Stretchy Hero Carousel
                if !viewModel.featuredInterests.isEmpty {
                    StretchyHeroCarousel(
                        interests: viewModel.featuredInterests,
                        interestPreviews: viewModel.interestPreviews,
                        navigationPath: $navigationPath
                    )
                }
                
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
                
                // Regular trending interests section (excluding featured ones)
                if viewModel.isLoadingTrendingInterests && viewModel.trendingInterests.isEmpty {
                    TrendingInterestsSectionPlaceholder()
                        .transition(.opacity)
                } else if !viewModel.trendingInterests.isEmpty {
                    TrendingInterestsSection(
                        viewModel: viewModel,
                        navigationPath: $navigationPath
                    )
                    .transition(.opacity)
                }
                
                PostGrid(
                    posts: $viewModel.posts,
                    onItemAppear: nil, // Disable item-based pagination
                    adsEnabled: true // Enable ads on discover feed
                )
                
                // Reusable Pagination Footer
                PaginationFooter(viewModel: viewModel)
            }
            .ignoresSafeArea()
            .animation(.smooth, value: viewModel.featuredInterests.count)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingTrendingInterests)
            .animation(.easeInOut(duration: 0.3), value: viewModel.recommendedUsers.count)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingRecommendedUsers)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "scroll")
    }
    
    // MARK: - Helper Methods
    
    private func handleRefresh() async {
        let toast = ToastValue(
            icon: Image(systemName: "arrow.triangle.2.circlepath"),
            message: "Refreshing..."
        )
        presentToast(toast)
        
        await viewModel.loadPosts()
        await viewModel.loadSuggestedUsers()
        await viewModel.loadRecommendedUsers()
        await viewModel.loadTrendingInterests()
        
        // Reload previews and reselect featured interests after interests are loaded
        if !viewModel.trendingInterests.isEmpty {
            await viewModel.loadInterestPreviews()
            viewModel.selectFeaturedInterests()
        }
    }
}

// MARK: - Stretchy Hero Carousel

/// A clean, standardized stretchy header carousel implementation.
/// The header stretches when the user pulls down, and snaps back when released.
struct StretchyHeroCarousel: View {
    let interests: [TrendingInterest]
    let interestPreviews: [String: [Post]]
    @Binding var navigationPath: NavigationPath
    
    private let baseHeight: CGFloat = StretchyHeaderConfig.baseHeight
    
    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .named("scroll")).minY
            // Calculate stretch: when pulling down (minY > 0), add to height
            let stretch = max(0, minY)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(interests) { interest in
                        HeroCard(
                            interest: interest,
                            previewPosts: interestPreviews[interest.id] ?? [],
                            baseHeight: baseHeight,
                            stretch: stretch
                        ) {
                            navigationPath.append(interest)
                        }
                        .containerRelativeFrame(.horizontal)
                        .clipped()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .frame(height: baseHeight + stretch)
            // When pulling down (minY > 0), offset upward to keep pinned at top
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(height: baseHeight)
    }
}

// MARK: - Hero Card

/// Individual card in the stretchy carousel.
/// Receives stretch amount from parent and applies it to the image.
private struct HeroCard: View {
    let interest: TrendingInterest
    let previewPosts: [Post]
    let baseHeight: CGFloat
    let stretch: CGFloat
    let onTap: () -> Void
    
    @State private var currentImageIndex: Int = 0
    @State private var slideshowTask: Task<Void, Never>?
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var isCheckingFollowStatus = true
    
    private let interestFollowService = InterestFollowService.shared
    
    // Limit to first 3-4 images for slideshow
    private var slideshowPosts: [Post] {
        Array(previewPosts.prefix(3))
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Background images - slideshow with fade transition
                heroImageSlideshow
                    .frame(height: baseHeight + stretch)
                    .clipped()
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.4),
                        .black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content overlay
                VStack(alignment: .leading, spacing: 0) {
                    // Follow button in top right
                    HStack {
                        Spacer()
                        followButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // Interest info and preview thumbnails at bottom
                    HStack(alignment: .bottom) {
                        // Interest info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                Text(interest.name)
                                    .font(.creatoDisplayHeadline())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 8)
                                
                                if interest.growthRate > 0 {
                                    GrowthBadge(rate: interest.growthRate)
                                }
                            }
                            
                            Text("\(interest.postCount) posts")
                                .font(.creatoDisplayCaption(.regular))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Preview thumbnails
                        PreviewThumbnails(posts: previewPosts)
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            startSlideshow()
        }
        .onDisappear {
            stopSlideshow()
        }
        .task {
            await checkFollowStatus()
        }
    }
    
    @ViewBuilder
    private var followButton: some View {
        if isCheckingFollowStatus {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
        } else {
            Button(action: {
                Task {
                    await toggleFollow()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.creatoDisplayCaption(.medium))
                }
                .foregroundColor(isFollowing ? .primary : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isFollowing
                        ? Color.white.opacity(0.3)
                        : Color.ora,
                    in: .capsule
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }
    
    private func checkFollowStatus() async {
        isCheckingFollowStatus = true
        do {
            isFollowing = try await interestFollowService.isFollowingInterest(
                interestId: interest.id
            )
        } catch {
            print("❌ HeroCard: Failed to check follow status: \(error.localizedDescription)")
            isFollowing = false
        }
        isCheckingFollowStatus = false
    }
    
    private func toggleFollow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if isFollowing {
                try await interestFollowService.unfollowInterest(
                    interestId: interest.id
                )
                isFollowing = false
            } else {
                try await interestFollowService.followInterest(
                    interestId: interest.id
                )
                isFollowing = true
                
                // Notify feed to refresh
                NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
            }
        } catch {
            print("❌ HeroCard: Failed to toggle follow: \(error.localizedDescription)")
        }
    }
    
    @ViewBuilder
    private var heroImageSlideshow: some View {
        if slideshowPosts.isEmpty {
            fallbackGradient
        } else {
            ZStack {
                // Show all images with opacity based on current index
                ForEach(Array(slideshowPosts.enumerated()), id: \.element.id) { index, post in
                    heroImage(for: post)
                        .opacity(index == currentImageIndex ? 1 : 0)
                        .animation(.easeInOut(duration: 1.5), value: currentImageIndex)
                }
            }
        }
    }
    
    @ViewBuilder
    private func heroImage(for post: Post) -> some View {
        if let urlString = post.thumbnailUrl ?? Optional(post.imageUrl),
           let url = URL(string: urlString) {
            KFImage(url)
                .placeholder { fallbackGradient }
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            fallbackGradient
        }
    }
    
    private var fallbackGradient: some View {
        LinearGradient(
            colors: [Color.accent.opacity(0.8), Color.accent.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Slideshow Timer
    
    private func startSlideshow() {
        // Only start slideshow if we have multiple images
        guard slideshowPosts.count > 1 else { return }
        
        // Stop any existing slideshow
        stopSlideshow()
        
        // Start new slideshow task
        slideshowTask = Task { @MainActor in
            while !Task.isCancelled {
                // Wait 3 seconds before changing image
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                
                guard !Task.isCancelled else { break }
                
                // Fade to next image
                withAnimation(.easeInOut(duration: 1.5)) {
                    currentImageIndex = (currentImageIndex + 1) % slideshowPosts.count
                }
            }
        }
    }
    
    private func stopSlideshow() {
        slideshowTask?.cancel()
        slideshowTask = nil
    }
}

// MARK: - Growth Badge

private struct GrowthBadge: View {
    let rate: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.up.right")
                .font(.caption2)
            Text("\(Int(rate * 100))%")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

// MARK: - Preview Thumbnails

private struct PreviewThumbnails: View {
    let posts: [Post]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(posts.dropFirst().prefix(2)), id: \.id) { post in
                thumbnailImage(for: post)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
        }
    }
    
    @ViewBuilder
    private func thumbnailImage(for post: Post) -> some View {
        if let urlString = post.thumbnailUrl ?? Optional(post.imageUrl),
           let url = URL(string: urlString) {
            KFImage(url)
                .placeholder { Color.white.opacity(0.2) }
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.white.opacity(0.2)
        }
    }
}

// MARK: - TrendingInterestsSection

struct TrendingInterestsSection: View {
    @ObservedObject var viewModel: DiscoverFeedViewModel
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            interestsScrollView
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var interestsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Show all interests except featured ones (they're in the hero section)
                let featuredInterestIds = Set(viewModel.featuredInterests.map { $0.id })
                let regularInterests = viewModel.trendingInterests.filter { !featuredInterestIds.contains($0.id) }
                
                ForEach(regularInterests) { interest in
                    TrendingInterestButton(
                        interest: interest,
                        navigationPath: $navigationPath
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}


// MARK: - TrendingInterestButton

struct TrendingInterestButton: View {
    let interest: TrendingInterest
    @Binding var navigationPath: NavigationPath
    
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var isCheckingFollowStatus = true
    
    private let interestFollowService = InterestFollowService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Main button for navigation
            Button(action: {
                navigationPath.append(interest)
            }) {
                HStack(spacing: 4) {
                    Text(interest.name)
                        .font(.subheadline)
                        .fontWeight(.regular)
                    
                    if interest.growthRate > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    
                    Text("(\(interest.postCount))")
                        .font(.caption2)
                        .opacity(0.7)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            // Follow button (separate from navigation)
            if isCheckingFollowStatus {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else {
                Button(action: {
                    Task {
                        await toggleFollow()
                    }
                }) {
                    Image(systemName: isFollowing ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(isFollowing ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .task {
            await checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() async {
        isCheckingFollowStatus = true
        do {
            isFollowing = try await interestFollowService.isFollowingInterest(
                interestId: interest.id
            )
        } catch {
            print("❌ TrendingInterestButton: Failed to check follow status: \(error.localizedDescription)")
            isFollowing = false
        }
        isCheckingFollowStatus = false
    }
    
    private func toggleFollow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if isFollowing {
                try await interestFollowService.unfollowInterest(
                    interestId: interest.id
                )
                isFollowing = false
            } else {
                try await interestFollowService.followInterest(
                    interestId: interest.id
                )
                isFollowing = true
                
                // Notify feed to refresh
                NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
            }
        } catch {
            print("❌ TrendingInterestButton: Failed to toggle follow: \(error.localizedDescription)")
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
            VStack(spacing: 20) {
                profileImageView(size: 90)
                userInfoView
                
                if canFollow {
                    followButton
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(.quinary,in: .rect(cornerRadius: 20))
            .containerRelativeFrame(.horizontal, count: 2, spacing: 10)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            currentUserId = Auth.auth().currentUser?.uid
            await loadFollowState()
        }
    }
    
    // MARK: - Subviews
    
    private func profileImageView(size: CGFloat = 70) -> some View {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var userInfoView: some View {
        VStack(spacing: 4) {
            Text(user.displayName ?? user.username)
                .font(.creatoDisplayHeadline(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("@\(user.username)")
                .font(.creatoDisplayBody(.regular))
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
                            .font(.system(size: 14, weight: .semibold))
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.creatoDisplayCallout(.medium))
                    }
                }
            }
            .foregroundColor(isFollowing ? .primary : .black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
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

struct StretchyHeroPlaceholder: View {
    private let baseHeight: CGFloat = StretchyHeaderConfig.baseHeight
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    HeroCardPlaceholder(height: baseHeight)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .frame(height: baseHeight)
    }
}

struct HeroCardPlaceholder: View {
    let height: CGFloat
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background shimmer
            LinearGradient(
                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content placeholder
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 180, height: 24)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 80, height: 14)
                }
                Spacer()
            }
            .padding(16)
        }
        .frame(height: height)
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

struct TrendingInterestsSectionPlaceholder: View {
    private let widths: [CGFloat] = [70, 85, 60, 90, 75, 65, 80, 95]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { index in
                        TrendingInterestButtonPlaceholder(width: widths[index % widths.count])
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct TrendingInterestButtonPlaceholder: View {
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

