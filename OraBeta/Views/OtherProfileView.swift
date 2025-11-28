//
//  OtherProfileView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import SwiftUI
import FirebaseAuth
import MasonryStack

struct OtherProfileView: View {
    let userId: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: OtherProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isBlocked = false
    @State private var showBlockConfirmation = false
    @State private var showUnblockConfirmation = false
    @State private var isBlocking = false
    private let blockedUsersService = BlockedUsersService()
    
    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: OtherProfileViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if let profile = viewModel.profile {
                        // Profile Header
                        VStack(spacing: 12) {
                            // Profile Photo
                            AsyncImage(url: URL(string: profile.profilePhotoUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            
                            // Username
                            if let displayName = profile.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            // Bio
                            if let bio = profile.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.creatoDisplayBody(.regular))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Location
                            if let location = profile.location, !location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text(location)
                                        .font(.creatoDisplaySubheadline())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            
                            // Website Link
                            if let websiteLink = profile.websiteLink, !websiteLink.isEmpty {
                                if let url = createURL(from: websiteLink) {
                                    Link(destination: url) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "link.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                            Text(websiteLink)
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.top, 4)
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Social Links
                            if let socialLinks = profile.socialLinks, !socialLinks.isEmpty {
                                HStack(spacing: 20) {
                                    ForEach(Array(socialLinks.keys.sorted()), id: \.self) { platform in
                                        if let urlString = socialLinks[platform], !urlString.isEmpty,
                                           let url = createURL(from: urlString) {
                                            Link(destination: url) {
                                                Image(systemName: iconForPlatform(platform))
                                                    .font(.title2)
                                                    .foregroundColor(.primary)
                                                    .frame(width: 36, height: 36)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 12)
                            }
                            
                            // Stats
                            HStack(spacing: 30) {
                                VStack {
                                    Text("\(profile.followerCount)")
                                        .font(.creatoDisplayHeadline())
                                    Text("Followers")
                                        .font(.creatoDisplayCaption())
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(profile.followingCount)")
                                        .font(.creatoDisplayHeadline())
                                    Text("Following")
                                        .font(.creatoDisplayCaption())
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(viewModel.posts.count)")
                                        .font(.creatoDisplayHeadline())
                                    Text(viewModel.posts.count == 1 ? "Post" : "Posts")
                                        .font(.creatoDisplayCaption())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                            
                            // Follow Button
                            followButton()
                                .padding(.top, 16)
                        }
                        .padding()
                        
                        sectionSwitcher()
                        
                        switch viewModel.section {
                        case .posts:
                            OtherUserPostsFeed(viewModel: viewModel)
                                .transition(.opacity)
                        case .boards:
                            OtherUserBoardsFeed(viewModel: viewModel)
                                .transition(.opacity)
                        }
                       
                    } else {
                        Text("Failed to load profile")
                            .foregroundColor(.red)
                    }
                }
            }
            .animation(.smooth, value: viewModel.section)
            .scrollIndicators(.hidden)
            .navigationTitle(viewModel.profile?.username ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: isBlocked ? .destructive : .none, action: {
                            if isBlocked {
                                showUnblockConfirmation = true
                            } else {
                                showBlockConfirmation = true
                            }
                        }) {
                            Label(
                                isBlocked ? "Unblock User" : "Block User",
                                systemImage: isBlocked ? "checkmark.shield.fill" : "hand.raised.fill"
                            )
                        }
                        .disabled(isBlocking)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Block User", isPresented: $showBlockConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Block", role: .destructive) {
                    Task {
                        await blockUser()
                    }
                }
            } message: {
                Text("Are you sure you want to block this user? You won't be able to see their posts or interact with them.")
            }
            .alert("Unblock User", isPresented: $showUnblockConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Unblock", role: .destructive) {
                    Task {
                        await unblockUser()
                    }
                }
            } message: {
                Text("Are you sure you want to unblock this user?")
            }
            .task {
                await viewModel.loadInitialData()
                await checkBlockStatus()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
    
    @ViewBuilder
    private func followButton() -> some View {
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
    
    private func checkBlockStatus() async {
        do {
            isBlocked = try await blockedUsersService.isUserBlocked(blockedId: userId)
        } catch {
            Logger.error("Failed to check block status: \(error.localizedDescription)", service: "OtherProfileView")
        }
    }
    
    private func blockUser() async {
        isBlocking = true
        do {
            try await blockedUsersService.blockUser(blockedId: userId)
            isBlocked = true
            // Unfollow if following
            if viewModel.isFollowing {
                await viewModel.toggleFollow()
            }
        } catch {
            Logger.error("Failed to block user: \(error.localizedDescription)", service: "OtherProfileView")
        }
        isBlocking = false
    }
    
    private func unblockUser() async {
        isBlocking = true
        do {
            try await blockedUsersService.unblockUser(blockedId: userId)
            isBlocked = false
        } catch {
            Logger.error("Failed to unblock user: \(error.localizedDescription)", service: "OtherProfileView")
        }
        isBlocking = false
    }
    
    @ViewBuilder
    private func sectionSwitcher() -> some View {
        HStack(spacing: 20) {
            Button { viewModel.section = .posts } label: {
                Text("Posts")
                    .font(.creatoDisplayTitle2())
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.section == .posts ? .accent : .secondary)
            }
            .buttonStyle(.plain)
                
            Button { viewModel.section = .boards } label: {
                Text("Boards")
                    .font(.creatoDisplayTitle2())
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.section == .boards ? .accent : .secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal)
        .animation(.smooth, value: viewModel.section)
    }
    
    private func createURL(from urlString: String) -> URL? {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        } else {
            return URL(string: "https://\(urlString)")
        }
    }
    
    private func iconForPlatform(_ platform: String) -> String {
        let lowercased = platform.lowercased()
        switch lowercased {
        case "twitter", "x":
            return "at"
        case "instagram":
            return "camera.fill"
        case "facebook":
            return "f.circle.fill"
        case "linkedin":
            return "link.circle.fill"
        case "tiktok":
            return "music.note"
        case "youtube":
            return "play.circle.fill"
        case "snapchat":
            return "camera.circle.fill"
        case "pinterest":
            return "pin.circle.fill"
        default:
            return "link.circle.fill"
        }
    }
}

struct OtherUserPostsFeed: View {
    @ObservedObject var viewModel: OtherProfileViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoadingPosts && viewModel.posts.isEmpty {
                ProgressView()
                    .padding()
            } else if viewModel.posts.isEmpty {
                VStack(spacing: 8) {
                    Text("No posts yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("This user hasn't posted anything yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                LazyVStack(spacing: 0) {
                    // Use 2-column grid for other profiles
                    PostGrid(
                        posts: $viewModel.posts,
                        columns: 2,
                        onItemAppear: nil,
                        adsEnabled: false // Disable ads on profile pages
                    )
                    
                    // Reusable Pagination Footer
                    PaginationFooter(viewModel: viewModel)
                }
            }
        }
    }
}

struct OtherUserBoardsFeed: View {
    @ObservedObject var viewModel: OtherProfileViewModel
    var body: some View {
        BoardsGrid(boards: viewModel.boards)
    }
}

#Preview {
    OtherProfileView(userId: "preview")
        .environmentObject(AuthViewModel())
        .previewAuthenticated(email: "nickswoke@outlook.com", password: "password1")
}
