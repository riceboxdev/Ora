//
//  ProfileView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth
import MasonryStack

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: ProfileViewModel
    @State private var showSettings = false
    @State private var isSelectionMode = false
    @State private var selectedPostIds: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    init() {
        // Create ViewModel with DIContainer services
        _viewModel = StateObject(wrappedValue: ProfileViewModel())
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
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        
                        sectionSwitcher()
                        
                        switch viewModel.section {
                        case .posts:
                            UserPostsFeed(
                                viewModel: viewModel,
                                isSelectionMode: $isSelectionMode,
                                selectedPostIds: $selectedPostIds
                            )
                            .transition(.opacity)
                        case .boards:
                            UserBoardsFeed(viewModel: viewModel)
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
                    Button(action: {
                        showSettings = true
                    }) {
                        Image("ellipsis.solid")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .task {
                await viewModel.loadInitialData()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
                    .onDisappear {
                        // Reload profile when SettingsView is dismissed in case profile was edited
                        Task {
                            await viewModel.loadProfile()
                        }
                    }
            }
            .alert("Delete \(selectedPostIds.count) Post\(selectedPostIds.count > 1 ? "s" : "")?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deletePosts()
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func deletePosts() async {
        isDeleting = true
        let postsToDelete = Array(selectedPostIds)
        
        // Delete posts one by one
        for postId in postsToDelete {
            do {
                try await viewModel.deletePost(postId: postId)
                await MainActor.run {
                    _ = selectedPostIds.remove(postId)
                }
            } catch {
                print("❌ Failed to delete post \(postId): \(error)")
            }
        }
        
        isDeleting = false
        isSelectionMode = false
        selectedPostIds.removeAll()
        
        // Refresh posts
        await viewModel.loadPosts()
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
            
            // Show controls only when in posts section
            if viewModel.section == .posts {
                HStack(spacing: 12) {
                    // Done button (only in selection mode)
                    if isSelectionMode {
                        Button("Done") {
                            isSelectionMode = false
                            selectedPostIds.removeAll()
                        }
                        .foregroundColor(.accentColor)
                    }
                    
                    // Ellipsis menu
                    Menu {
                        if !isSelectionMode {
                            Button(role: .destructive, action: {
                                isSelectionMode = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .animation(.smooth, value: viewModel.section)
        .animation(.smooth, value: isSelectionMode)
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

struct UserPostsFeed: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isSelectionMode: Bool
    @Binding var selectedPostIds: Set<String>
    
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
                    Text("Start sharing your moments!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                LazyVStack(spacing: 0) {
                    // Custom grid with selection support
                    if isSelectionMode {
                        SelectablePostGrid(
                            posts: viewModel.posts,
                            selectedPostIds: $selectedPostIds,
                            onLoadMore: {
                                // No-op for now, using footer trigger
                            }
                        )
                    } else {
                        // Use standard PostGrid instead of PaginatedPostGrid
                        PostGrid(
                            posts: $viewModel.posts,
                            columns: 3,
                            onItemAppear: nil // Disable item-based pagination
                        )
                    }
                    
                    // Reusable Pagination Footer
                    PaginationFooter(viewModel: viewModel)
                }
            }
        }
    }
}

// Deprecated: PaginatedPostGrid is replaced by PostGrid + PaginationFooter
// Keeping it for reference if needed, but it's no longer used in UserPostsFeed

struct SelectablePostGrid: View {
    let posts: [Post]
    @Binding var selectedPostIds: Set<String>
    let onLoadMore: () -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 5),
            GridItem(.flexible(), spacing: 5),
            GridItem(.flexible(), spacing: 5)
        ], spacing: 5) {
            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                SelectablePostCell(
                    post: post,
                    isSelected: selectedPostIds.contains(post.id),
                    onTap: {
                        if selectedPostIds.contains(post.id) {
                            selectedPostIds.remove(post.id)
                        } else {
                            selectedPostIds.insert(post.id)
                        }
                    }
                )
                .onAppear {
                    // Load more when approaching end (last 5 items)
                    if index >= posts.count - 5 {
                        onLoadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 5)
    }
}

struct SelectablePostCell: View {
    let post: Post
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: post.effectiveThumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(height: 200)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                onTap()
            }
            
            // Selection checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .white)
                .font(.title2)
                .padding(8)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .padding(8)
        }
    }
}

struct UserBoardsFeed: View {
    @ObservedObject var viewModel: ProfileViewModel
    var body: some View {
        BoardsGrid(boards: viewModel.boards)
    }
}

enum ProfileTabSection: String, CaseIterable {
    case posts = "Posts"
    case boards = "Boards"
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .previewAuthenticated(email: "nickswoke@outlook.com", password: "password1")
}

