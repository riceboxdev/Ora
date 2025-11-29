//
//  RelatedUsersSection.swift
//  OraBeta
//
//  Component displaying users who create similar content to a post
//

import SwiftUI
import FirebaseAuth
import Kingfisher

// MARK: - RelatedUsersSection

/// Section displaying users who create similar content to the current post
struct RelatedUsersSection: View {
    let users: [UserProfile]
    let isLoading: Bool
    let profileService: ProfileServiceProtocol
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Similar Creators")
                    .font(.creatoDisplayHeadline(.medium))
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            if isLoading && users.isEmpty {
                // Loading placeholder
                RelatedUsersPlaceholder()
            } else if users.isEmpty {
                // Empty state
                EmptyRelatedUsersView()
            } else {
                // Users scroll view
                usersScrollView
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var usersScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(users) { user in
                    RelatedUserCard(
                        user: user,
                        profileService: profileService
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - RelatedUserCard

/// Card displaying a related user with follow functionality
struct RelatedUserCard: View {
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
            VStack(spacing: 10) {
                profileImageView
                userInfoView
                
                if canFollow {
                    followButton
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 110)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
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
        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var userInfoView: some View {
        VStack(spacing: 2) {
            Text(user.displayName ?? user.username)
                .font(.creatoDisplayCaption(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("@\(user.username)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
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
                        .scaleEffect(0.6)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 9, weight: .semibold))
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
            }
            .foregroundColor(isFollowing ? .primary : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
            print("⚠️ RelatedUserCard: Failed to load follow state: \(error.localizedDescription)")
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
            print("❌ RelatedUserCard: Failed to toggle follow: \(error.localizedDescription)")
            isFollowing = wasFollowing
        }
        
        isLoading = false
    }
}

// MARK: - Placeholder Views

struct RelatedUsersPlaceholder: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    RelatedUserCardPlaceholder()
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RelatedUserCardPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            // Profile image placeholder
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 60)
            
            // User info placeholder
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 70, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 50, height: 10)
            }
            
            // Follow button placeholder
            Capsule()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 24)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 110)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyRelatedUsersView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "person.2.slash")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No similar creators found")
                    .font(.creatoDisplayCaption(.regular))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        RelatedUsersSection(
            users: [],
            isLoading: true,
            profileService: DIContainer.shared.profileService
        )
        
        RelatedUsersSection(
            users: [],
            isLoading: false,
            profileService: DIContainer.shared.profileService
        )
    }
}




