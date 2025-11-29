//
//  CommentSheet.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import Foundation
import FirebaseAuth

struct CommentSheet: View {
    let post: Post
    let viewModel: PostDetailViewModel?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    private let profileService = ProfileService()
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var userProfiles: [String: UserProfile] = [:]
    
    init(post: Post, viewModel: PostDetailViewModel? = nil) {
        self.post = post
        self.viewModel = viewModel
    }
    
    // Create engagement service
    private var engagementService: EngagementService {
        return EngagementService()
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if comments.isEmpty {
                    Spacer()
                    Text("No comments yet")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(comments) { comment in
                        CommentRowView(
                            comment: comment,
                            profile: userProfiles[comment.userId]
                        )
                    }
                    .listStyle(.plain)
//                    .listRowSeparator(.visible, edges: .all)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Comment Input
                HStack {
                    TextField("Add a comment...", text: $newCommentText)
                        .padding(.horizontal)
                        .frame(height: 45)
                        .glassEffect(.regular.interactive())
                    Button(action: {
                        Task {
                            await addComment()
                        }
                    }) {
                        Image(systemName: "arrow.up")
                            .fontWeight(.semibold)
                            .foregroundStyle(.whiteui)
                          
                    }
                    .disabled(newCommentText.isEmpty || isLoading)
                    .buttonStyle(.glassProminent)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await engagementService.getComments(postId: post.id, postAuthorId: post.userId)
            
            // Load user profiles for all comments
            await loadUserProfiles(for: comments)
        } catch {
            print("Error loading comments: \(error)")
        }
        isLoading = false
    }
    
    private func loadUserProfiles(for comments: [Comment]) async {
        // Get unique user IDs that we don't already have
        let existingUserIds = Set(userProfiles.keys)
        let userIdsToLoad = Set(comments.map { $0.userId }).subtracting(existingUserIds)
        
        guard !userIdsToLoad.isEmpty else {
            return
        }
        
        // Load profiles in parallel
        var newProfiles: [String: UserProfile] = [:]
        
        await withTaskGroup(of: (String, UserProfile?).self) { group in
            for userId in userIdsToLoad {
                group.addTask {
                    do {
                        let profile = try await profileService.getUserProfile(userId: userId)
                        return (userId, profile)
                    } catch {
                        print("Error loading profile for user \(userId): \(error)")
                        return (userId, nil)
                    }
                }
            }
            
            // Collect results
            for await (userId, profile) in group {
                if let profile = profile {
                    newProfiles[userId] = profile
                }
            }
        }
        
        // Update state with new profiles
        if !newProfiles.isEmpty {
            userProfiles.merge(newProfiles) { (_, new) in new }
        }
    }
    
    private func addComment() async {
        guard !newCommentText.isEmpty else { return }
        
        isLoading = true
        do {
            try await engagementService.commentOnPost(
                postId: post.id,
                text: newCommentText
            )
            
            // Track comment event with Algolia Insights
            await AlgoliaInsightsService.shared.trackComment(objectID: post.id)
            
            newCommentText = ""
            await loadComments()
            
            // Refresh comment count in viewModel if available
            if let viewModel = viewModel {
                await viewModel.loadCommentCount()
            }
        } catch {
            print("Error adding comment: \(error)")
        }
        isLoading = false
    }
}

struct CommentRowView: View {
    let comment: Comment
    let profile: UserProfile?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Photo
            AsyncImage(url: URL(string: profile?.profilePhotoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Comment Content
            VStack(alignment: .leading, spacing: 4) {
                // Username
                Text(profile?.username ?? profile?.displayName ?? "User \(comment.userId)")
                    .font(.creatoDisplayHeadline(.bold))
                    .foregroundColor(.primary)
                
                // Comment Text
                Text(comment.text)
                    .font(.creatoDisplayBody(.regular))
                    .foregroundColor(.primary)
                
                // Timestamp
                Text(comment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
//        .padding(.vertical, 4)
//        .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
//
//            // 2
//            return 0
//        }
//        .listRowBackground(Color.quinary)
    }
}

#Preview {
    CommentSheet(
        post: Post(
            activityId: "post_0bULA5bM4OhI71GC5V0JhGiRvGG3_1763484083787_43txw48",
            userId: "0bULA5bM4OhI71GC5V0JhGiRvGG3",
            imageUrl: "https://example.com/image.jpg"
        ),
        viewModel: nil
    )
    .environmentObject(AuthViewModel())
    .previewAuthenticated(email: "nickswoke@outlook.com", password: "password1")
}

