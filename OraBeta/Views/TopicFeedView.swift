//
//  TopicFeedView.swift
//  OraBeta
//
//  Created for displaying posts filtered by a specific trending topic
//

import SwiftUI
import Combine
import Foundation

struct TopicFeedView: View {
    let topic: TrendingTopic
    @StateObject private var viewModel: TopicFeedViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(topic: TrendingTopic) {
        self.topic = topic
        _viewModel = StateObject(wrappedValue: TopicFeedViewModel(topic: topic))
    }
    
    var body: some View {
        contentView
            .navigationTitle(topic.name)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadPosts()
            }
            .task {
                await viewModel.loadInitialData()
                await viewModel.checkFollowStatus()
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            loadingView
        } else if viewModel.posts.isEmpty {
            emptyStateView
        } else {
            feedScrollView
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No posts found")
                .font(.creatoDisplayHeadline())
                .foregroundColor(.primary)
            
            Text("There are no posts for this topic yet.")
                .font(.creatoDisplayBody())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: ViewConstants.Layout.defaultSpacing) {
                // Topic info header
                topicInfoHeader
                
                // Posts grid
                PostGrid(
                    posts: $viewModel.posts,
                    onItemAppear: { post in
                        // Load more when reaching the end
                        if post.id == viewModel.posts.last?.id && viewModel.hasMore && !viewModel.isLoadingMore {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    },
                    adsEnabled: true // Enable ads on topic feed
                )
                
                // Loading indicator for pagination
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
                
                // End of feed message
                if !viewModel.hasMore && !viewModel.posts.isEmpty {
                    Text("You've reached the end")
                        .font(.creatoDisplayCaption(.regular))
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var topicInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(topic.name)
                    .font(.creatoDisplayHeadline())
                    .fontWeight(.bold)
                
                Spacer()
                
                // Follow button
                Button(action: {
                    Task {
                        await viewModel.toggleFollow()
                    }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isFollowing {
                            Image(systemName: "checkmark")
                                .font(.caption)
                        }
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                            .font(.creatoDisplayCaption(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        viewModel.isFollowing
                            ? Color.accentColor.opacity(0.1)
                            : Color.accentColor
                    )
                    .foregroundColor(
                        viewModel.isFollowing
                            ? .accentColor
                            : .white
                    )
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTogglingFollow)
                
                if topic.growthRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                        Text("\(Int(topic.growthRate * 100))%")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Label("\(topic.postCount) posts", systemImage: "photo.on.rectangle")
                    .font(.creatoDisplayCaption(.regular))
                    .foregroundColor(.secondary)
                
                if let engagement = topic.metadata?.avgLikes {
                    Label(String(format: "%.0f likes", engagement), systemImage: "heart")
                        .font(.creatoDisplayCaption(.regular))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.vertical, 8)
    }
}

// MARK: - TopicFeedViewModel

@MainActor
class TopicFeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    @Published var isFollowing = false
    @Published var isTogglingFollow = false
    
    private let topic: TrendingTopic
    private let trendService = TrendService.shared
    private let topicFollowService = TopicFollowService.shared
    private let pageSize = 20
    private var lastLoadedPostIds: Set<String> = []
    
    init(topic: TrendingTopic) {
        self.topic = topic
    }
    
    func checkFollowStatus() async {
        do {
            isFollowing = try await topicFollowService.isFollowingTopic(
                topicName: topic.name,
                topicType: topic.type
            )
        } catch {
            Logger.warning("Failed to check follow status: \(error.localizedDescription)", service: "TopicFeedViewModel")
        }
    }
    
    func toggleFollow() async {
        guard !isTogglingFollow else { return }
        
        isTogglingFollow = true
        
        do {
            if isFollowing {
                try await topicFollowService.unfollowTopic(
                    topicName: topic.name,
                    topicType: topic.type
                )
                isFollowing = false
            } else {
                try await topicFollowService.followTopic(
                    topicName: topic.name,
                    topicType: topic.type
                )
                isFollowing = true
            }
        } catch {
            Logger.error("Failed to toggle follow: \(error.localizedDescription)", service: "TopicFeedViewModel")
            errorMessage = "Failed to update follow status"
        }
        
        isTogglingFollow = false
    }
    
    func loadInitialData() async {
        guard posts.isEmpty else { return }
        await loadPosts()
    }
    
    func loadPosts() async {
        isLoading = true
        errorMessage = nil
        lastLoadedPostIds.removeAll()
        hasMore = true
        
        do {
            let fetchedPostsData = try await trendService.getPostsByTopic(
                topicId: topic.name,
                topicType: topic.type,
                limit: pageSize,
                timeWindow: topic.timeWindow
            )
            
            // Convert [[String: Any]] to [Post]
            var fetchedPosts: [Post] = []
            for postDict in fetchedPostsData {
                if let postId = postDict["id"] as? String ?? postDict["activityId"] as? String {
                    if let post = await Post.from(firestoreData: postDict, documentId: postId) {
                        fetchedPosts.append(post)
                    }
                }
            }
            
            self.posts = fetchedPosts
            self.lastLoadedPostIds = Set(fetchedPosts.map { $0.id })
            self.hasMore = fetchedPosts.count >= pageSize
            
            print("✅ TopicFeedViewModel: Loaded \(fetchedPosts.count) posts for topic '\(topic.name)'")
        } catch let error as TrendError {
            // Handle specific TrendError cases
            switch error {
            case .notAuthenticated:
                errorMessage = "Please sign in to view posts"
            case .networkError:
                errorMessage = "Network error. Please check your connection."
            case .invalidResponse:
                errorMessage = "Invalid response from server"
            case .missingIndex(let message):
                errorMessage = "Configuration error: \(message)"
            case .functionError(let message):
                errorMessage = message
            }
            print("❌ TopicFeedViewModel: Failed to load posts: \(error.localizedDescription)")
            self.posts = []
            self.hasMore = false
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            print("❌ TopicFeedViewModel: Failed to load posts: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            self.posts = []
            self.hasMore = false
        }
        
        isLoading = false
    }
    
    func loadMorePosts() async {
        guard hasMore && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            // Fetch more posts (enough to account for already loaded ones)
            let currentCount = posts.count
            let fetchedPostsData = try await trendService.getPostsByTopic(
                topicId: topic.name,
                topicType: topic.type,
                limit: currentCount + pageSize,
                timeWindow: topic.timeWindow
            )
            
            // Convert [[String: Any]] to [Post]
            var fetchedPosts: [Post] = []
            for postDict in fetchedPostsData {
                if let postId = postDict["id"] as? String ?? postDict["activityId"] as? String {
                    if let post = await Post.from(firestoreData: postDict, documentId: postId) {
                        fetchedPosts.append(post)
                    }
                }
            }
            
            // Filter out posts we've already loaded
            let newPosts = fetchedPosts.filter { !lastLoadedPostIds.contains($0.id) }
            
            if newPosts.isEmpty {
                hasMore = false
                print("⚠️ TopicFeedViewModel: No more posts for topic '\(topic.name)'")
            } else {
                self.posts.append(contentsOf: newPosts)
                self.lastLoadedPostIds.formUnion(Set(newPosts.map { $0.id }))
                self.hasMore = newPosts.count >= pageSize
                
                print("✅ TopicFeedViewModel: Loaded \(newPosts.count) more posts for topic '\(topic.name)'")
            }
        } catch {
            print("❌ TopicFeedViewModel: Failed to load more posts: \(error.localizedDescription)")
            hasMore = false
        }
        
        isLoadingMore = false
    }
}

