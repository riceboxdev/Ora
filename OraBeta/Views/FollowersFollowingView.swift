//
//  FollowersFollowingView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import Combine
import FirebaseAuth

struct FollowersFollowingView: View {
    let userId: String
    let type: ListType
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: FollowersFollowingViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    enum ListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers:
                return "Followers"
            case .following:
                return "Following"
            }
        }
    }
    
    init(userId: String, type: ListType) {
        self.userId = userId
        self.type = type
        _viewModel = StateObject(wrappedValue: FollowersFollowingViewModel(userId: userId, type: type))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.users.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: type == .followers ? "person.2" : "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No \(type.title.lowercased()) yet")
                            .font(.creatoDisplayHeadline())
                            .foregroundColor(.secondary)
                        Text(type == .followers 
                             ? "When someone follows this user, they'll appear here"
                             : "When this user follows someone, they'll appear here")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.users) { user in
                            NavigationLink(destination: OtherProfileView(userId: user.id ?? "")) {
                                UserRow(user: user, profileService: viewModel.profileService)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadUsers()
            }
        }
    }
}

struct UserRow: View {
    let user: UserProfile
    let profileService: ProfileServiceProtocol
    @State private var isFollowing = false
    @State private var isFollowingUser = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            AsyncImage(url: URL(string: user.profilePhotoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.username)
                    .font(.creatoDisplaySubheadline(.medium))
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.creatoDisplayCaption(.regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Follow button (only show if not current user)
            if let userId = user.id,
               userId != Auth.auth().currentUser?.uid {
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
                            ? Color(UIColor.tertiarySystemFill)
                            : Color.ora,
                        in: .capsule
                    )
                }
                .buttonStyle(.plain)
                .disabled(isFollowingUser)
                .task {
                    await checkFollowStatus()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func checkFollowStatus() async {
        guard let userId = user.id else { return }
        do {
            isFollowing = try await profileService.isFollowing(followingId: userId)
        } catch {
            print("❌ UserRow: Failed to check follow status: \(error.localizedDescription)")
        }
    }
    
    private func toggleFollow() async {
        guard let userId = user.id else { return }
        isFollowingUser = true
        defer { isFollowingUser = false }
        
        do {
            if isFollowing {
                try await profileService.unfollowUser(followingId: userId)
                isFollowing = false
            } else {
                try await profileService.followUser(followingId: userId)
                isFollowing = true
            }
            
            // Notify feed to refresh
            NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
        } catch {
            print("❌ UserRow: Failed to toggle follow: \(error.localizedDescription)")
        }
    }
}

@MainActor
class FollowersFollowingViewModel: ObservableObject {
    let userId: String
    let type: FollowersFollowingView.ListType
    let profileService: ProfileServiceProtocol
    
    @Published var users: [UserProfile] = []
    @Published var isLoading = false
    
    init(userId: String, type: FollowersFollowingView.ListType, container: DIContainer? = nil) {
        self.userId = userId
        self.type = type
        let diContainer = container ?? DIContainer.shared
        self.profileService = diContainer.profileService
    }
    
    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch type {
            case .followers:
                users = try await profileService.getFollowers(userId: userId, limit: 100)
            case .following:
                users = try await profileService.getFollowing(userId: userId, limit: 100)
            }
            print("✅ FollowersFollowingViewModel: Loaded \(users.count) \(type.title.lowercased())")
        } catch {
            print("❌ FollowersFollowingViewModel: Failed to load \(type.title.lowercased()): \(error.localizedDescription)")
            users = []
        }
    }
}

#Preview {
    FollowersFollowingView(userId: "test", type: .followers)
        .environmentObject(AuthViewModel())
}

