//
//  SearchView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import MasonryStack

struct SearchView: View {
    let initialQuery: String?
    let isTopicContext: Bool // Whether this is opened from a topic/tag context
    
    @State private var searchText = ""
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var currentQueryID: String? // For click tracking
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSearched = false // Track if we've performed initial search
    
    init(initialQuery: String? = nil, isTopicContext: Bool = false) {
        self.initialQuery = initialQuery
        self.isTopicContext = isTopicContext
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Search")
                .searchable(text: $searchText, prompt: "Search posts, tags, users...")
                .onChange(of: searchText) { oldValue, newValue in
                    // Debounce search - cancel previous task
                    searchTask?.cancel()
                    
                    // Clear results if search is empty
                    if newValue.isEmpty {
                        posts = []
                        currentQueryID = nil
                        return
                    }
                    
                    // Debounce: wait 300ms before searching
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                        
                        // Check if task was cancelled
                        guard !Task.isCancelled else { return }
                        
                        await search(query: newValue)
                    }
                }
                .onSubmit(of: .search) {
                    Task {
                        await search(query: searchText)
                    }
                }
                .task {
                    // Auto-search if initialQuery is provided
                    if let initialQuery = initialQuery, !hasSearched {
                        searchText = initialQuery
                        hasSearched = true
                        await search(query: initialQuery)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if posts.isEmpty && !searchText.isEmpty {
            VStack {
                Text("No results found")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if posts.isEmpty {
            VStack {
                Text("Search for posts, tags, or users")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Show follow topic row only in topic context (from tag/topic detail view)
                    if isTopicContext && !posts.isEmpty && !searchText.isEmpty {
                        FollowTopicRow(topicName: searchText, topicType: .tag)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }
                    
                    PostGrid(
                        posts: posts,
                        queryID: currentQueryID,
                        adsEnabled: false // Disable ads in search results
                    )
                }
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func search(query: String) async {
        guard !query.isEmpty else {
            posts = []
            currentQueryID = nil
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await AlgoliaSearchService.shared.searchPosts(query: query)
            posts = result.posts
            currentQueryID = result.queryID
            
            print("✅ SearchView: Found \(result.nbHits) total results, showing \(posts.count) posts")
        } catch {
            print("❌ SearchView: Search failed: \(error.localizedDescription)")
            posts = []
            currentQueryID = nil
        }
    }
    
}

// MARK: - FollowTopicRow Component

struct FollowTopicRow: View {
    let topicName: String
    let topicType: TrendingTopic.TopicType
    
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var isCheckingFollowStatus = true
    
    private let topicFollowService = TopicFollowService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Topic name with hash
            Text("#\(topicName)")
                .font(.creatoDisplaySubheadline(.medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Follow/Unfollow button
            if isCheckingFollowStatus {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    Task {
                        await toggleFollow()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.creatoDisplayCaption(.medium))
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 2))
        .task {
            await checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() async {
        isCheckingFollowStatus = true
        do {
            isFollowing = try await topicFollowService.isFollowingTopic(
                topicName: topicName,
                topicType: topicType
            )
        } catch {
            print("❌ FollowTopicRow: Failed to check follow status: \(error.localizedDescription)")
            isFollowing = false
        }
        isCheckingFollowStatus = false
    }
    
    private func toggleFollow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if isFollowing {
                try await topicFollowService.unfollowTopic(
                    topicName: topicName,
                    topicType: topicType
                )
                isFollowing = false
            } else {
                try await topicFollowService.followTopic(
                    topicName: topicName,
                    topicType: topicType
                )
                isFollowing = true
                
                // Notify feed to refresh
                NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
            }
        } catch {
            print("❌ FollowTopicRow: Failed to toggle follow: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SearchView()
}

#Preview("With Initial Query") {
    SearchView(initialQuery: "flowers")
}

