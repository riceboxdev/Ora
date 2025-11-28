//
//  PostTaggingViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class PostTaggingViewModel: ObservableObject {
    @Published var currentPost: Post?
    @Published var currentPostIndex: Int = 0
    @Published var totalPosts: Int = 0
    @Published var selectedTags: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    
    private let db = Firestore.firestore()
    private let tagService = TagService.shared
    private var untaggedPosts: [Post] = []
    
    /// Load posts without tags for current user
    func loadUntaggedPosts() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Query posts without tags or with empty tags array
            let snapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Filter posts that don't have tags or have empty tags
            var posts: [Post] = []
            for doc in snapshot.documents {
                let data = doc.data()
                // Check if tags field is missing, null, or empty array
                let hasTags: Bool
                if !data.keys.contains("tags") {
                    hasTags = false // No tags field
                } else if let tags = data["tags"] as? [String] {
                    hasTags = !tags.isEmpty
                } else {
                    hasTags = false // Tags is null
                }
                
                if !hasTags {
                    // Try to create Post from Firestore data
                    if let post = await Post.from(firestoreData: data, documentId: doc.documentID, profiles: [:]) {
                        posts.append(post)
                    }
                }
            }
            untaggedPosts = posts
            
            totalPosts = untaggedPosts.count
            currentPostIndex = 0
            
            if untaggedPosts.isEmpty {
                isComplete = true
            } else {
                loadCurrentPost()
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Load current post for tagging
    private func loadCurrentPost() {
        guard currentPostIndex < untaggedPosts.count else {
            isComplete = true
            return
        }
        
        currentPost = untaggedPosts[currentPostIndex]
        selectedTags = []
        errorMessage = nil
    }
    
    /// Save tags for current post and move to next
    func saveTagsAndContinue() async {
        guard let post = currentPost else { return }
        guard !selectedTags.isEmpty else {
            errorMessage = "Please add at least 1 tag"
            return
        }
        
        // Validate tags
        let tagArray = Array(selectedTags)
        do {
            let validation = try await tagService.validateTags(tagArray)
            if !validation.valid {
                errorMessage = validation.error ?? "Invalid tags"
                return
            }
        } catch {
            errorMessage = "Failed to validate tags: \(error.localizedDescription)"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Update post with tags
            try await db.collection("posts").document(post.id).updateData([
                "tags": tagArray,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Move to next post
            currentPostIndex += 1
            
            if currentPostIndex >= untaggedPosts.count {
                isComplete = true
            } else {
                loadCurrentPost()
            }
            
            isSaving = false
        } catch {
            errorMessage = "Failed to save tags: \(error.localizedDescription)"
            isSaving = false
        }
    }
    
    /// Get current post ID for context-aware suggestions
    func getCurrentPostId() -> String? {
        return currentPost?.id
    }
    
    /// Check if user has untagged posts (for blocking UI)
    func hasUntaggedPosts() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        do {
            // Query posts for this user and check if any have empty or missing tags
            let snapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .limit(to: 50) // Check up to 50 posts
                .getDocuments()
            
            // Check if any post has empty or missing tags
            for doc in snapshot.documents {
                let data = doc.data()
                // Check if tags field is missing, null, or empty array
                if !data.keys.contains("tags") {
                    return true // No tags field
                }
                if let tags = data["tags"] as? [String], tags.isEmpty {
                    return true // Empty tags array
                }
                if data["tags"] == nil {
                    return true // Tags is null
                }
            }
            
            return false
        } catch {
            print("⚠️ PostTaggingViewModel: Error checking untagged posts: \(error.localizedDescription)")
            return false
        }
    }
}
