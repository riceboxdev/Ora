//
//  InterestFeedView.swift
//  OraBeta
//
//  Feed view filtered by a specific interest
//  Displays posts that contain the interest ID in their interestIds array
//

import SwiftUI
import FirebaseAuth

struct InterestFeedView: View {
    let interest: TrendingInterest
    @StateObject private var viewModel: InterestFeedViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(interest: TrendingInterest) {
        self.interest = interest
        _viewModel = StateObject(wrappedValue: InterestFeedViewModel(interest: interest))
    }
    
    // MARK: - Body
    
    var body: some View {
        contentView
            .navigationTitle(interest.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    followButton
                }
            }
            .task {
                await viewModel.loadPosts()
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
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No posts yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Be the first to post about \(interest.name)!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Interest header info
                interestHeaderView
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                
                Divider()
                
                // Posts grid
                PostGrid(
                    posts: $viewModel.posts,
                    onItemAppear: nil,
                    adsEnabled: false
                )
                
                // Pagination footer
                PaginationFooter(viewModel: viewModel)
            }
        }
        .refreshable {
            await viewModel.loadPosts()
        }
    }
    
    private var interestHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Interest name and stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(interest.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Label("\(interest.postCount)", systemImage: "doc.text")
                        Label("\(interest.followerCount)", systemImage: "person.2")
                        
                        if interest.growthRate > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                Text("\(Int(interest.growthRate * 100))%")
                            }
                            .font(.caption)
                            .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Description
            if let description = interest.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
    
    @ViewBuilder
    private var followButton: some View {
        if viewModel.isCheckingFollowStatus {
            ProgressView()
                .scaleEffect(0.8)
        } else {
            Button(action: {
                Task {
                    await viewModel.toggleFollow()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.isFollowing ? "Following" : "Follow")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .foregroundColor(viewModel.isFollowing ? .primary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    viewModel.isFollowing
                        ? Color(UIColor.tertiarySystemFill)
                        : Color.accentColor,
                    in: .capsule
                )
            }
            .disabled(viewModel.isLoadingFollow)
        }
    }
}

#Preview {
    NavigationStack {
        InterestFeedView(
            interest: TrendingInterest(
                interest: Interest(
                    id: "fashion",
                    name: "fashion",
                    displayName: "Fashion",
                    level: 0,
                    postCount: 1234,
                    followerCount: 567
                )
            )
        )
    }
}
