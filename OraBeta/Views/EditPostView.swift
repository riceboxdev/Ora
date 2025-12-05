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
    @State private var selectedInterests: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInterestSheet = false
    
    private let postService = PostService(profileService: ProfileService())
    
    init(post: Post) {
        self.post = post
        _caption = State(initialValue: post.caption ?? "")
        _selectedInterests = State(initialValue: Set(post.interestIds ?? []))
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
                
                // Interests
                Section(header: Text("Interests (Required: 1-5)")) {
                    if selectedInterests.isEmpty {
                        Button {
                            showInterestSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Interests")
                            }
                            .foregroundColor(.accentColor)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedInterests), id: \.self) { interestId in
                                    Button {
                                        selectedInterests.remove(interestId)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(interestId)
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.2))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        Button {
                            showInterestSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add More")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
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
                    .disabled(isSaving || selectedInterests.isEmpty)
                }
            }
            .sheet(isPresented: $showInterestSheet) {
                NavigationView {
                    VStack {
                        InterestAutocompleteView(
                            selectedInterests: $selectedInterests,
                            minInterests: 1,
                            maxInterests: 5
                        )
                        .padding()
                        Spacer()
                    }
                    .navigationTitle("Select Interests")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showInterestSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
    }
    
    private func saveChanges() async {
        guard !selectedInterests.isEmpty else {
            errorMessage = "Please add at least 1 interest"
            showErrorAlert = true
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Prepare updated values
            let updatedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalCaption = updatedCaption.isEmpty ? nil : updatedCaption
            let interests = Array(selectedInterests)
            
            // Call PostService to edit the post
            try await postService.editPost(
                postId: post.id,
                caption: finalCaption,
                interestIds: interests
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
            interestIds: ["fashion", "photography"]
        )
    )
    .environmentObject(AuthViewModel())
}

