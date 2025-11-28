//
//  HomeFeedView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import MasonryStack
import Boomerang

struct HomeFeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: HomeFeedViewModel
    
    // Memory optimization: Use direct singleton reference instead of StateObject
    private let queueService = UploadQueueService.shared
    
    @State private var showUploader = false
    @State private var selectedTopicId: String? = nil // For sensory feedback optimization
    
    init() {
        // Create ViewModel with DIContainer services
        _viewModel = StateObject(wrappedValue: HomeFeedViewModel())
    }
    
    // Computed property for cleaner alert binding
    private var showVerificationAlert: Binding<Bool> {
        Binding(
            get: { viewModel.verificationResult != nil },
            set: { if !$0 { viewModel.verificationResult = nil } }
        )
    }
    
    var body: some View {
        NavigationStack {
            feedContent
                .transition(.opacity)
                // Combined animation for better performance
                .animation(ViewConstants.Animation.smooth, value: viewModel.posts.map { $0.id })
                .refreshable {
                    await viewModel.loadPosts()
                    await viewModel.loadPersonalizedTrendingTopics()
                    // If posts are still empty after refresh, reload recommendations
                    if viewModel.posts.isEmpty {
                        await viewModel.loadRecommendations()
                    }
                }
                .sheet(isPresented: $showUploader) {
                    CreatePostView()
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showUploader = true
                        } label: {
                            Image("plus.solid")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: ViewConstants.Toolbar.buttonSize, height: ViewConstants.Toolbar.buttonSize)
                        }
                        .shadow(radius: 6)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .alert("Stream Follows Status", isPresented: showVerificationAlert) {
                    Button("OK") {
                        viewModel.verificationResult = nil
                    }
                } message: {
                    if let result = viewModel.verificationResult {
                        Text(result)
                    }
                }
                .task {
                    // Configure upload queue service
                    queueService.initializeServices()
                    await viewModel.loadInitialData()
                }
                .onReceive(NotificationCenter.default.publisher(for: Foundation.Notification.Name.feedShouldRefresh)) { _ in
                    // Refresh feed when follow/unfollow notification is received
                    Task {
                        print("🔄 HomeFeedView: Received feed refresh notification")
                        await viewModel.loadPosts()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            loadingView
        } else if viewModel.posts.isEmpty {
            emptyFeedView
        } else {
            postsFeedView
        }
    }
    
    private var loadingView: some View {
        VStack {
            UploadQueueCard(queueService: queueService)
                .transition(.opacity.combined(with: .move(edge: .top)))
            Spacer()
            ProgressView()
            Spacer()
        }
        .transition(.opacity)
    }
    
    private var emptyFeedView: some View {
        ScrollView {
            VStack(spacing: 0) {
                UploadQueueCard(queueService: queueService)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                if viewModel.isLoadingRecommendations {
                    LoadingIndicator(padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if !viewModel.recommendations.isEmpty {
                    FollowRecommendationsView(
                        recommendations: viewModel.recommendations,
                        profileService: viewModel.profileService
                    )
                } else {
                    VStack {
                        Text("No posts yet")
                            .foregroundColor(.secondary)
                        Text("Follow users to see their posts in your feed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
    }
    
    private var postsFeedView: some View {
        ScrollView {
            LazyVStack(spacing: ViewConstants.Layout.defaultSpacing) {
                UploadQueueCard(queueService: queueService)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                // Show trending topics section if we have topics, or if we're loading (to show loading state)
                if !viewModel.trendingTopics.isEmpty || viewModel.isLoadingTrendingTopics {
                    HomeTrendingTopicsSection(
                        trendingTopics: viewModel.trendingTopics,
                        isLoadingTrendingTopics: viewModel.isLoadingTrendingTopics,
                        selectedTrendingTopic: viewModel.selectedTrendingTopic,
                        onTopicSelected: { topic in
                            await viewModel.filterByTrendingTopic(topic)
                            // Optimized sensory feedback - only trigger when actually changing
                            if selectedTopicId != topic?.id {
                                selectedTopicId = topic?.id
                            }
                        }
                    )
                    .sensoryFeedback(.selection, trigger: selectedTopicId)
                }
                
                PostGrid(
                    posts: $viewModel.posts,
                    onItemAppear: nil // Disable item-based pagination
                )
                
                
                // Reusable Pagination Footer
                PaginationFooter(viewModel: viewModel)
            }
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
    }
}

#Preview {
    HomeFeedView()
        .previewAuthenticated()
}

#Preview("Admin User") {
    HomeFeedView()
        .previewAdmin()
}

#Preview("Custom User") {
    HomeFeedView()
        .previewAuthenticated(
            email: "test@example.com",
            password: "password123",
            username: "testuser"
        )
}

#Preview("Custom Admin") {
    HomeFeedView()
        .previewAdmin(
            email: "customadmin@example.com",
            password: "adminpass123",
            username: "customadmin"
        )
}
