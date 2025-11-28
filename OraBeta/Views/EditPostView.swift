//
//  EditPostView.swift
//  OraBeta
//
//  Created for editing user's own posts
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct EditPostView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var caption: String
    @State private var selectedTags: Set<String>
    @State private var categories: [String]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    private let postService = PostService(profileService: ProfileService())
    
    init(post: Post) {
        self.post = post
        _caption = State(initialValue: post.caption ?? "")
        _selectedTags = State(initialValue: Set(post.tags ?? []))
        _categories = State(initialValue: post.categories ?? [])
    }
    
    var body: some View {
        Form {
                // Post preview
                Section(header: Text("Post Preview")) {
                    KFImage(URL(string: post.imageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                }
                
                // Caption
                Section(header: Text("Caption")) {
                    TextField("Write a caption...", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Tags
                Section(header: Text("Tags (Required: 1-5)")) {
                    TagAutocompleteView(
                        selectedTags: $selectedTags,
                        semanticLabels: nil,
                        postId: post.id,
                        minTags: 1,
                        maxTags: 5
                    )
                }
                
                // Categories (optional)
                Section(header: Text("Categories (Optional)")) {
                    // Simple text field for categories - can be enhanced later
                    Text("Categories editing coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(isSaving || selectedTags.isEmpty)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }
    
    private func saveChanges() async {
        guard !selectedTags.isEmpty else {
            errorMessage = "Please add at least 1 tag"
            showErrorAlert = true
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Prepare updated values
            let updatedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalCaption = updatedCaption.isEmpty ? nil : updatedCaption
            let tagsArray = Array(selectedTags)
            
            // Call PostService to edit the post
            try await postService.editPost(
                postId: post.id,
                caption: finalCaption,
                tags: tagsArray,
                categories: categories.isEmpty ? nil : categories
            )
            
            // Success - dismiss the view
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showErrorAlert = true
            isSaving = false
        }
    }
}

#Preview {
    EditPostView(
        post: Post(
            activityId: "test-post",
            userId: "test-user",
            username: "testuser",
            imageUrl: "https://picsum.photos/400/600",
            caption: "Test caption",
            tags: ["nature", "landscape"]
        )
    )
    .environmentObject(AuthViewModel())
}

