//
//  FeedPostView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct FeedPostView: View {
    let post: Post
    @State private var isLiked = false
    @State private var showComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                AsyncImage(url: URL(string: post.userProfilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                Text(post.username ?? "Unknown")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Image
            AsyncImage(url: URL(string: post.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(post.aspectRatio.map { CGFloat($0) }, contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(post.aspectRatio.map { CGFloat($0) } ?? 1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }
            
            // Engagement Buttons
            HStack(spacing: 20) {
                Button(action: {
                    isLiked.toggle()
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                        .font(.title2)
                }
                
                Button(action: {
                    showComments = true
                }) {
                    Image(systemName: "bubble.right")
                        .font(.title2)
                }
                
                Spacer()
                
                Text("\(post.likeCount) likes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Caption
            if let caption = post.caption, !caption.isEmpty {
                HStack {
                    Text("\(post.username ?? "Unknown") \(caption)")
                        .font(.body)
                }
                .padding(.horizontal)
            }
            
            // Comments count
            if post.commentCount > 0 {
                Button(action: {
                    showComments = true
                }) {
                    Text("View all \(post.commentCount) comments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentSheet(post: post)
        }
    }
}

#Preview {
    FeedPostView(
        post: Post(
            activityId: "1",
            userId: "user1",
            username: "testuser",
            imageUrl: "https://example.com/image.jpg",
            imageWidth: 1080,
            imageHeight: 1080,
            caption: "Test caption"
        )
    )
}

