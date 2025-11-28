//
//  FollowRecommendationsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct FollowRecommendationsView: View {
    let recommendations: [FollowRecommendation]
    let profileService: ProfileServiceProtocol
    @State private var followingStates: [String: Bool] = [:]
    @State private var isLoadingStates: [String: Bool] = [:]
    @State private var userProfiles: [String: UserProfile] = [:]
    @State private var isLoadingProfiles = true
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discover People")
                        .font(.creatoDisplayTitle2())
                        .fontWeight(.bold)
                    
                    Text("Follow users to see their posts in your feed")
                        .font(.creatoDisplayBody(.regular))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Recommendations List
                if isLoadingProfiles {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if recommendations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No recommendations available")
                            .font(.creatoDisplayBody(.regular))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(recommendations) { recommendation in
                            RecommendationRow(
                                recommendation: recommendation,
                                profile: userProfiles[recommendation.id],
                                isFollowing: followingStates[recommendation.id] ?? false,
                                isLoading: isLoadingStates[recommendation.id] ?? false,
                                currentUserId: currentUserId,
                                onFollowToggle: {
                                    await toggleFollow(for: recommendation)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadUserProfiles()
            await loadFollowingStates()
        }
    }
    
    private func loadUserProfiles() async {
        isLoadingProfiles = true
        
        await withTaskGroup(of: (String, UserProfile?).self) { group in
            for recommendation in recommendations {
                group.addTask {
                    do {
                        if let profile = try await profileService.getUserProfile(userId: recommendation.id) {
                            return (recommendation.id, profile)
                        }
                    } catch {
                        print("⚠️ Failed to load profile for \(recommendation.id): \(error.localizedDescription)")
                    }
                    return (recommendation.id, nil)
                }
            }
            
            for await (userId, profile) in group {
                if let profile = profile {
                    userProfiles[userId] = profile
                }
            }
        }
        
        isLoadingProfiles = false
    }
    
    private func loadFollowingStates() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        await withTaskGroup(of: (String, Bool).self) { group in
            for recommendation in recommendations {
                // Skip if it's the current user
                guard recommendation.id != currentUserId else {
                    continue
                }
                
                group.addTask {
                    do {
                        let isFollowing = try await profileService.isFollowing(followingId: recommendation.id)
                        return (recommendation.id, isFollowing)
                    } catch {
                        print("⚠️ Failed to check follow status for \(recommendation.id): \(error.localizedDescription)")
                        return (recommendation.id, false)
                    }
                }
            }
            
            for await (userId, isFollowing) in group {
                followingStates[userId] = isFollowing
            }
        }
    }
    
    private func toggleFollow(for recommendation: FollowRecommendation) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              recommendation.id != currentUserId else {
            return
        }
        
        let userId = recommendation.id
        let currentlyFollowing = followingStates[userId] ?? false
        
        // Optimistically update UI
        isLoadingStates[userId] = true
        
        do {
            if currentlyFollowing {
                try await profileService.unfollowUser(followingId: userId)
                followingStates[userId] = false
            } else {
                try await profileService.followUser(followingId: userId)
                followingStates[userId] = true
                
                // Refresh feed after following
                NotificationCenter.default.post(name: Foundation.Notification.Name.feedShouldRefresh, object: nil)
            }
        } catch {
            print("❌ Failed to toggle follow for \(userId): \(error.localizedDescription)")
            // Revert optimistic update on error
            followingStates[userId] = currentlyFollowing
        }
        
        isLoadingStates[userId] = false
    }
}

struct RecommendationRow: View {
    let recommendation: FollowRecommendation
    let profile: UserProfile?
    let isFollowing: Bool
    let isLoading: Bool
    let currentUserId: String?
    let onFollowToggle: () async -> Void
    
    private var isCurrentUser: Bool {
        currentUserId == recommendation.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Photo
            Group {
                if let profilePhotoUrl = profile?.profilePhotoUrl,
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
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? profile?.username ?? "Unknown")
                    .font(.creatoDisplayHeadline())
                    .foregroundColor(.primary)
                
                if let username = profile?.username, username != profile?.displayName {
                    Text("@\(username)")
                        .font(.creatoDisplayCaption(.regular))
                        .foregroundColor(.secondary)
                }
                
                if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.creatoDisplayCaption(.regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Follow Button (only show if not current user)
            if !isCurrentUser {
                Button(action: {
                    Task {
                        await onFollowToggle()
                    }
                }) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: isFollowing ? "checkmark" : "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.creatoDisplayCaption(.medium))
                        }
                    }
                }
                .foregroundColor(isFollowing ? .primary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isFollowing
                        ? Color(UIColor.tertiarySystemFill)
                        : Color.ora,
                    in: .capsule
                )
            }
            .disabled(isLoading)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

#Preview {
    FollowRecommendationsView(
        recommendations: [
            FollowRecommendation(from: ["feed_id": "user:abc123", "score": 0.95])!,
            FollowRecommendation(from: ["feed_id": "user:def456", "score": 0.87])!
        ],
        profileService: ProfileService()
    )
}

