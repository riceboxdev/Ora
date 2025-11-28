//
//  PostDetailView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import OraBetaAdmin

struct PostDetailView: View {
    let post: Post
    let queryID: String? // For Algolia click tracking (from search results)
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PostDetailViewModel
    @State private var showComments = false
    @State private var isAdmin = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var showEditPost = false
    @State private var showStoryPreview = false
    @State private var showReportSheet = false
    
    @EnvironmentObject var container: DIContainer
    private var profileService: ProfileServiceProtocol {
        container.profileService
    }
    
    init(post: Post, feedGroup: String = "user", feedId: String? = nil, queryID: String? = nil) {
        self.post = post
        self.queryID = queryID
        // Create ViewModel with DIContainer services - feedGroup and feedId are kept for backwards compatibility
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(post: post, feedGroup: feedGroup, feedId: feedId))
    }
    
    // Check if current user owns the post
    private var isOwnPost: Bool {
        guard let currentUserId = authViewModel.currentUser?.uid else {
            return false
        }
        return post.userId == currentUserId
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                postImageSection
                engagementStatsSection
                EngagementRow(viewModel: viewModel)
                captionSection
                tagsSection
                latestCommentSection
                recommendedPostsSection
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Post")
        .animation(.smooth, value: viewModel.likeCount)
        .animation(.smooth, value: viewModel.commentCount)
        .animation(.smooth, value: viewModel.showBoards)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deletePost()
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentSheet(post: post, viewModel: viewModel)
        }
        .sheet(isPresented: $showEditPost) {
            NavigationView {
                EditPostView(post: post)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showStoryPreview) {
            StoryPreviewView(post: post)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostSheet(post: post)
                .environmentObject(authViewModel)
        }
        .task {
            await setupView()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var postImageSection: some View {
        PostImagePreview(viewModel: viewModel)
    }
    
    @ViewBuilder
    private var engagementStatsSection: some View {
        HStack {
            likesText
            Spacer()
            commentsText
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var likesText: some View {
        Text("\(viewModel.likeCount) likes")
            .font(.creatoDisplaySubheadline(.medium))
            .contentTransition(.numericText(value: Double(viewModel.likeCount)))
    }
    
    @ViewBuilder
    private var commentsText: some View {
        Text("\(viewModel.commentCount) comments")
            .font(.creatoDisplaySubheadline(.medium))
            .contentTransition(.numericText(value: Double(viewModel.commentCount)))
    }
    
    @ViewBuilder
    private var captionSection: some View {
        if let caption = post.caption, !caption.isEmpty {
            Text(caption)
                .font(.creatoDisplayBody())
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        if let tags = post.tags, !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        NavigationLink(destination: SearchView()) {
                            Text("#\(tag)")
                                .font(.creatoDisplayBody())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(height: 50)
                                .background(.regularMaterial, in: .rect(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var latestCommentSection: some View {
        Group {
            if let latestComment = viewModel.latestComment {
                Button(action: {
                    showComments = true
                }) {
                    latestCommentView
                }
                .buttonStyle(PlainButtonStyle())
            } else if viewModel.commentCount > 0 {
                Button(action: {
                    showComments = true
                }) {
                    HStack {
                        Text("View all \(viewModel.commentCount) comments")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            } else {
                Button { showComments = true } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 32, height: 32)
                        
                        Text("Be the first to comment")
                            .font(.creatoDisplaySubheadline(.regular))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 50)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private var latestCommentView: some View {
        if let latestComment = viewModel.latestComment {
            HStack(alignment: .top, spacing: 12) {
                // Profile photo
                AsyncImage(url: URL(string: viewModel.latestCommentProfile?.profilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                // Comment content
                VStack(alignment: .leading, spacing: 4) {
                    // Username and comment text (inline)
                    HStack(alignment: .top, spacing: 6) {
                        Text(viewModel.latestCommentProfile?.username ?? viewModel.latestCommentProfile?.displayName ?? "User")
                            .font(.creatoDisplayBody())
                            .fontWeight(.semibold)
                        
                        Text(latestComment.text)
                            .font(.creatoDisplayBody())
                            .foregroundColor(.primary)
                    }
                    
                    // Timestamp
                    Text(latestComment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var recommendedPostsSection: some View {
        if !viewModel.recommendedPosts.isEmpty {
            RecommendedPostsSection(
                posts: viewModel.recommendedPosts,
                isLoading: viewModel.isLoadingRecommendations
            )
        } else if viewModel.isLoadingRecommendations {
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                // Edit option (only show for post owner)
                if isOwnPost {
                    Button(action: {
                        showEditPost = true
                    }) {
                        Label("Edit Post", systemImage: "pencil")
                    }
                    Divider()
                }
                
                // Delete option (only show for post owner)
                if isOwnPost {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Post", systemImage: "trash")
                    }
                    Divider()
                }
                
                // Report and block (only show for other users' posts)
                if !isOwnPost {
                    Button(action: {
                        showReportSheet = true
                    }) {
                        Label("Report", systemImage: "exclamationmark.bubble")
                    }
                    
                    Button(action: {
                        // TODO: Implement block functionality
                        print("Block user tapped")
                    }) {
                        Label("Block User", systemImage: "hand.raised")
                    }
                }
                
                // Add to Story option (show for all posts except own expired stories)
                Button(action: {
                    showStoryPreview = true
                }) {
                    Label("Add to Story", systemImage: "plus.circle")
                }
                
                // Admin-only options
                if isAdmin {
                    if !isOwnPost {
                        Divider()
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = post.id
                    }) {
                        Label("Copy Post ID", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
            }
            .disabled(isDeleting)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupView() async {
        await viewModel.loadInitialState()
        await checkAdminStatus()
        
        // Track view with existing analytics service
        await trackView()
        
        // Track view with Algolia Insights
        // Note: Algolia does not support positions for view events (only for click events)
        await AlgoliaInsightsService.shared.trackView(objectID: post.id)
        
        // Track click event with Algolia Insights (when user navigates to detail view)
        // If queryID is provided (from search results), use it for better tracking
        if let queryID = queryID {
            // This is from a search result - track with queryID
            // Note: We don't have position here, but queryID is the important part
            await AlgoliaInsightsService.shared.trackClick(objectID: post.id, queryID: queryID)
        } else {
            // Regular navigation (not from search) - track without queryID
            await AlgoliaInsightsService.shared.trackClick(objectID: post.id)
        }
    }
    
    // MARK: - Helper Functions
    
    private func deletePost() async {
        guard isOwnPost else {
            deleteError = "You can only delete your own posts"
            showDeleteError = true
            return
        }
        
        isDeleting = true
        deleteError = nil
        
        do {
            // Use PostService from container
            let postService = container.postService
            
            // Use post.id (which is the same as activityId) as the postId
            try await postService.deletePost(postId: post.id)
            
            print("✅ PostDetailView: Post deleted successfully")
            
            // Dismiss the view after successful deletion
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ PostDetailView: Failed to delete post: \(error.localizedDescription)")
            deleteError = "Failed to delete post: \(error.localizedDescription)"
            showDeleteError = true
        }
        
        isDeleting = false
    }
    
    private func checkAdminStatus() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        
        do {
            isAdmin = try await profileService.isAdmin(userId: userId)
        } catch {
            print("❌ PostDetailView: Error checking admin status: \(error.localizedDescription)")
            isAdmin = false
        }
    }
    
    private func trackView() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let analyticsService = FeedAnalyticsService()
        do {
            // Track view with position (0 for detail view)
            try await analyticsService.trackView(
                postId: post.id,
                userId: userId,
                duration: nil,
                position: 0
            )
        } catch {
            print("⚠️ PostDetailView: Failed to track view: \(error.localizedDescription)")
            // Non-critical, don't block UI
        }
    }
}

struct PostImagePreview: View {
    @ObservedObject var viewModel: PostDetailViewModel
    var cornerRadius: CGFloat = 30
    
    private var imageURL: URL? {
        URL(string: viewModel.post.imageUrl)
    }
    
    @State private var isPressed: Bool = false
    @State private var showLikeAnimation: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Image - no downsampling for full-size detail view
            CachedImageView(
                url: imageURL,
                aspectRatio: viewModel.post.aspectRatio.map { CGFloat($0) },
                downsamplingSize: nil, // Full-size image
                contentMode: .fit
            )
            .aspectRatio(viewModel.post.aspectRatio.map { CGFloat($0) }, contentMode: .fit)
            .onLongPressGesture {
                self.isPressed = true
            } onPressingChanged: { isPressed in
                if isPressed == false {
                    self.isPressed = false
                }
            }
            .onTapGesture(count: 2) {
                // Double tap to like
                handleDoubleTap()
            }
            
            if !isPressed {
                PostInfoRow(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .overlay {
            // Like animation overlay
            if showLikeAnimation {
                Image("heart.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: showLikeAnimation)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 2))
        .shadow(radius: 8)
        .transition(.opacity)
        .animation(.smooth, value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showLikeAnimation)
    }
    
    private func handleDoubleTap() {
        // Only like if not already liked
        guard !viewModel.isLiked else { return }
        
        // Show animation
        withAnimation {
            showLikeAnimation = true
        }
        
        // Hide animation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showLikeAnimation = false
            }
        }
        
        // Toggle like
        Task {
            await viewModel.toggleLike()
        }
    }
}

struct PostInfoRow: View {
    @ObservedObject var viewModel: PostDetailViewModel
    let imageSize: CGFloat = 40
    
    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(destination: OtherProfileView(userId: viewModel.post.userId)) {
                AsyncImage(url: URL(string: viewModel.post.userProfilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image("defaultavatar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(width: imageSize, height: imageSize)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 15) {
                NavigationLink(destination: OtherProfileView(userId: viewModel.post.userId)) {
                    Text(viewModel.post.username ?? "Unknown")
                        .font(.creatoDisplayHeadline())
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Follow button - only show if current user is not the post owner
                if viewModel.canFollow {
                    Button(action: {
                        Task {
                            await viewModel.toggleFollow()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text(viewModel.isFollowing ? "Following" : "Follow")
                                .font(.creatoDisplayCaption(.medium))
                        }
                        .foregroundColor(viewModel.isFollowing ? .primary : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.isFollowing
                                ? Color(UIColor.tertiarySystemFill)
                                : Color.ora,
                            in: .capsule
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isFollowingUser)
                }
            }
            
            Spacer()

            LikeButton(viewModel: viewModel)
        }
        .padding(10)
        .background {
            LinearGradient(
                colors: [
                    .clear, .black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.smooth, value: viewModel.isFollowing)
    }
}

struct LikeButton: View {
    @ObservedObject var viewModel: PostDetailViewModel
    
    var body: some View {
        Button(action: {
            Task {
                await viewModel.toggleLike()
            }
        }) {
            Image("heart.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundStyle(viewModel.isLiked ? .red : .white.opacity(0.6))
                .symbolEffect(.bounce, value: viewModel.isLiked)
                .scaleEffect(viewModel.isLiked ? 1.1 : 1.0)
        }
        .disabled(viewModel.isLiking)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isLiked)
    }
}

struct EngagementRow: View {
    @ObservedObject var viewModel: PostDetailViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showCreateBoard = false
    let rowHeight: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                saveButton()
            }
            
            if viewModel.showBoards {
                VStack(spacing: 8) {
                    if viewModel.isLoadingBoards {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                        .frame(height: 50)
                    } else if viewModel.boards.isEmpty {
                        // Create Board option
                        Button(action: {
                            showCreateBoard = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create Board")
                                    .font(.creatoDisplayHeadline())
                                Spacer()
                            }
                            .foregroundStyle(.ora)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(height: 50)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                // Create Board option
                                Button(action: {
                                    showCreateBoard = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                        Text("Create")
                                            .font(.creatoDisplaySubheadline(.medium))
                                    }
                                    .foregroundStyle(.ora)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                
                                // Board list
                                ForEach(viewModel.boards) { board in
                                    boardRow(board: board)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .animation(.smooth, value: viewModel.showBoards)
        .sheet(isPresented: $showCreateBoard) {
            CreateBoardView(boardService: BoardService())
                .environmentObject(authViewModel)
                .onDisappear {
                    // Reload boards after creating a new one
                    Task {
                        await viewModel.loadBoards()
                    }
                }
        }
        .onChange(of: viewModel.showBoards) { oldValue, newValue in
            if newValue && viewModel.boards.isEmpty && !viewModel.isLoadingBoards {
                // Load boards when showing boards view
                Task {
                    await viewModel.loadBoards()
                }
            }
        }
    }
    
    @ViewBuilder
    private func boardRow(board: Board) -> some View {
        Button(action: {
            Task {
                await viewModel.saveToBoard(board)
            }
        }) {
            HStack(spacing: 12) {
                // Board cover image or placeholder
                Group {
                    if let coverImageUrl = board.coverImageUrl,
                       let url = URL(string: coverImageUrl),
                       !coverImageUrl.isEmpty {
                        CachedImageView(
                            url: url,
                            aspectRatio: 1.0,
                            downsamplingSize: CGSize(width: 50, height: 50),
                            contentMode: .fill
                        )
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo.stack")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(board.title)
                        .font(.creatoDisplayHeadline())
                        .lineLimit(1)
                    
                    if let description = board.description, !description.isEmpty {
                        Text(description)
                            .font(.creatoDisplayCaption(.regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("\(board.postCount) posts")
                        .font(.creatoDisplayCaption(.regular))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if viewModel.isSavingToBoard {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.ora)
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(height: 50)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingToBoard)
    }
    
    @ViewBuilder
    private func saveButton() -> some View {
        Button { 
            viewModel.showBoards.toggle()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("Save")
                    .font(.creatoDisplaySubheadline(.medium))
                
                Image(systemName: viewModel.showBoards ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.black)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(.ora, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recommended Posts Section

struct RecommendedPostsSection: View {
    let posts: [Post]
    let isLoading: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("think.love")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 25)
                    .foregroundStyle(.pink)
                Text("Recommended for you")
                    .font(.creatoDisplayHeadline())
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if posts.isEmpty {
                EmptyView()
            } else {
                // Use PostGrid with masonry layout to match discover and home feeds
                PostGrid(
                    posts: posts,
                    columns: 2,
                    spacing: 5
                )
            }
        }
        .padding(.vertical, 16)
    }
}


#Preview {
    NavigationView {
        PostDetailView(
            post: Post(
                activityId: "8408ea70-be85-11f0-8080-800050ac5f9f",
                userId: "ChXrUkIGqsS1TMVi6avPKAhIlxn1",
                username: "Nick",
                imageUrl: "https://res.cloudinary.com/ddlpzt0qn/image/upload/v1762550962/users/ChXrUkIGqsS1TMVi6avPKAhIlxn1/thumbnails/ekc8zxcxkg51rqb21hcb.jpg",
                caption: "Test caption",
                tags: ["flowers", "nature", "retro"]
            )
        )
    }
    .environmentObject(AuthViewModel())
    .environmentObject(DIContainer.shared)
    .previewAuthenticated(email: "nickswoke@outlook.com", password: "password1")
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}

// MARK: - StoryPreviewView
struct StoryPreviewView: View {
    let post: Post
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isCreatingStory = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var storyService: StoryServiceProtocol {
        StoryServiceContainer.shared.storyService
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Post Preview
                VStack(spacing: 12) {
                    Text("Story Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This post will be shared to your story for 24 hours")
                        .font(.creatoDisplayBody())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Post Image Preview
                    CachedImageView(
                        url: URL(string: post.effectiveThumbnailUrl),
                        aspectRatio: post.aspectRatio.map { CGFloat($0) },
                        downsamplingSize: CGSize(width: 300, height: 300),
                        contentMode: .fit
                    )
                    .frame(maxWidth: 200)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Post Caption
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.creatoDisplayBody())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("No caption")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await createStory()
                        }
                    }) {
                        HStack {
                            if isCreatingStory {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isCreatingStory ? "Creating Story..." : "Share to Story")
                                .font(.creatoDisplaySubheadline(.medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ora, in: .rect(cornerRadius: 12))
                    }
                    .disabled(isCreatingStory)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.creatoDisplaySubheadline(.medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func createStory() async {
        guard let userId = authViewModel.currentUser?.uid else {
            errorMessage = "You must be logged in to create a story"
            showError = true
            return
        }
        
        isCreatingStory = true
        errorMessage = nil
        
        do {
            let request = CreateStoryRequest(postId: post.id, userId: userId)
            let story = try await storyService.createStory(request: request)
            
            print("✅ StoryPreviewView: Story created successfully with ID: \(story.id ?? "unknown")")
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ StoryPreviewView: Failed to create story: \(error.localizedDescription)")
            errorMessage = "Failed to create story: \(error.localizedDescription)"
            showError = true
        }
        
        isCreatingStory = false
    }
}
