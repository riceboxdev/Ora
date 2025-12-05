//
//  BulkEditPostView.swift
//  OraBeta
//
//  Created for admin bulk editing of posts
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher
import Combine

struct BulkEditPostView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var viewModel = BulkEditPostViewModel()
    @State private var selectedOperation: BulkOperation = .addInterests
    @State private var showConfirmation = false
    
    enum BulkOperation: String, CaseIterable {
        case addInterests = "Add Interests"
        case removeInterests = "Remove Interests"
        case reassignPosts = "Reassign Posts"
        case deletePosts = "Delete Posts"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Operation selector
                Picker("Operation", selection: $selectedOperation) {
                    ForEach(BulkOperation.allCases, id: \.self) { operation in
                        Text(operation.rawValue).tag(operation)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected operation
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedOperation {
                        case .addInterests, .removeInterests:
                            interestBulkEditView
                        case .reassignPosts:
                            reassignPostsView
                        case .deletePosts:
                            deletePostsView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Bulk Edit Posts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        showConfirmation = true
                    }
                    .disabled(!viewModel.hasSelectedPosts || viewModel.isProcessing)
                }
            }
            .confirmationDialog("Confirm Bulk Operation", isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("Confirm", role: .destructive) {
                    Task {
                        await viewModel.performBulkOperation(selectedOperation)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(viewModel.getConfirmationMessage(for: selectedOperation))
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage ?? "Operation completed")
            }
            .task {
                await viewModel.loadPosts()
            }
        }
    }
    
    // MARK: - Interest Bulk Edit View
    
    private var interestBulkEditView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select posts and interests to \(selectedOperation == .addInterests ? "add" : "remove")")
                .font(.headline)
            
            // Interest input
            VStack(alignment: .leading, spacing: 8) {
                Text("Interests to \(selectedOperation == .addInterests ? "Add" : "Remove")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                InterestAutocompleteView(
                    selectedInterests: $viewModel.selectedBulkInterests,
                    minInterests: 1,
                    maxInterests: 10
                )
            }
            
            Divider()
            
            // Post selection
            postSelectionView
        }
    }
    
    // MARK: - Reassign Posts View
    
    private var reassignPostsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reassign selected posts to a different user")
                .font(.headline)
            
            // User ID input
            VStack(alignment: .leading, spacing: 8) {
                Text("New User ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter user ID", text: $viewModel.newUserId)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }
            
            Divider()
            
            postSelectionView
        }
    }
    
    // MARK: - Delete Posts View
    
    private var deletePostsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚠️ Warning: This will permanently delete selected posts")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("This action cannot be undone. Make sure you have selected the correct posts.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            postSelectionView
        }
    }
    

    
    // MARK: - Post Selection View
    
    private var postSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Posts")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Search bar
            TextField("Search posts by caption, interests, or user...", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                    viewModel.filterPosts()
                }
            
            // Selection controls
            HStack {
                Button("Select All") {
                    viewModel.selectAll()
                }
                .disabled(viewModel.filteredPosts.isEmpty)
                
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
                .disabled(viewModel.selectedPostIds.isEmpty)
                
                Spacer()
                
                Text("\(viewModel.selectedPostIds.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Posts list
            if viewModel.isLoading {
                ProgressView("Loading posts...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.filteredPosts.isEmpty {
                Text("No posts found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredPosts) { post in
                        BulkEditPostRow(
                            post: post,
                            isSelected: viewModel.selectedPostIds.contains(post.id),
                            onToggle: {
                                viewModel.toggleSelection(postId: post.id)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Bulk Edit Post Row

struct BulkEditPostRow: View {
    let post: Post
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                // Post thumbnail
                KFImage(URL(string: post.thumbnailUrl ?? post.imageUrl))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                
                // Post info
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    } else {
                        Text("No caption")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let interests = post.interestIds, !interests.isEmpty {
                        Text(interests.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("@\(post.username ?? "unknown")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk Edit Post ViewModel

@MainActor
class BulkEditPostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var filteredPosts: [Post] = []
    @Published var selectedPostIds: Set<String> = []
    @Published var selectedBulkInterests: Set<String> = []
    @Published var newUserId: String = ""
    @Published var searchQuery: String = ""
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    private let postService = PostService(profileService: ProfileService())
    private let profileService = ProfileService()
    
    var hasSelectedPosts: Bool {
        !selectedPostIds.isEmpty
    }
    
    func getConfirmationMessage(for operation: BulkEditPostView.BulkOperation) -> String {
        let count = selectedPostIds.count
        switch operation {
        case .addInterests:
            let interests = selectedBulkInterests.joined(separator: ", ")
            return "Add interests [\(interests)] to \(count) selected post\(count == 1 ? "" : "s")?"
        case .removeInterests:
            let interests = selectedBulkInterests.joined(separator: ", ")
            return "Remove interests [\(interests)] from \(count) selected post\(count == 1 ? "" : "s")?"
        case .reassignPosts:
            return "Reassign \(count) selected post\(count == 1 ? "" : "s") to user ID: \(newUserId)?"
        case .deletePosts:
            return "⚠️ Permanently delete \(count) selected post\(count == 1 ? "" : "s")? This cannot be undone!"
        }
    }
    
    func loadPosts() async {
        isLoading = true
        
        do {
            // Load all posts (admin can see all)
            let result = try await postService.getPosts(userId: nil, limit: 500)
            posts = result.posts
            filteredPosts = posts
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func filterPosts() {
        if searchQuery.isEmpty {
            filteredPosts = posts
        } else {
            let query = searchQuery.lowercased()
            filteredPosts = posts.filter { post in
                // Search in caption
                if let caption = post.caption?.lowercased(), caption.contains(query) {
                    return true
                }
                // Search in interests
                if let interests = post.interestIds, interests.contains(where: { $0.lowercased().contains(query) }) {
                    return true
                }
                // Search in username
                if let username = post.username?.lowercased(), username.contains(query) {
                    return true
                }
                return false
            }
        }
    }
    
    func selectAll() {
        selectedPostIds = Set(filteredPosts.map { $0.id })
    }
    
    func deselectAll() {
        selectedPostIds.removeAll()
    }
    
    func toggleSelection(postId: String) {
        if selectedPostIds.contains(postId) {
            selectedPostIds.remove(postId)
        } else {
            selectedPostIds.insert(postId)
        }
    }
    
    func performBulkOperation(_ operation: BulkEditPostView.BulkOperation) async {
        guard !selectedPostIds.isEmpty else {
            errorMessage = "Please select at least one post"
            showError = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let selectedPosts = posts.filter { selectedPostIds.contains($0.id) }
            var successCount = 0
            var errorCount = 0
            
            switch operation {
            case .addInterests:
                guard !selectedBulkInterests.isEmpty else {
                    errorMessage = "Please select interests to add"
                    showError = true
                    isProcessing = false
                    return
                }
                
                let interestsToAdd = Array(selectedBulkInterests)
                for post in selectedPosts {
                    do {
                        let currentInterests = Set(post.interestIds ?? [])
                        let updatedInterests = currentInterests.union(interestsToAdd)
                        // Limit to 5 interests max
                        let finalInterests = Array(updatedInterests.prefix(5))
                        try await postService.editPost(
                            postId: post.id,
                            caption: nil,
                            interestIds: finalInterests
                        )
                        successCount += 1
                    } catch {
                        errorCount += 1
                    }
                }
                successMessage = "Added interests to \(successCount) posts. \(errorCount) failed."
                
            case .removeInterests:
                guard !selectedBulkInterests.isEmpty else {
                    errorMessage = "Please select interests to remove"
                    showError = true
                    isProcessing = false
                    return
                }
                
                let interestsToRemove = Array(selectedBulkInterests)
                for post in selectedPosts {
                    do {
                        let currentInterests = Set(post.interestIds ?? [])
                        let updatedInterests = currentInterests.subtracting(interestsToRemove)
                        // Ensure at least 1 interest remains
                        if !updatedInterests.isEmpty {
                            try await postService.editPost(
                                postId: post.id,
                                caption: nil,
                                interestIds: Array(updatedInterests)
                            )
                            successCount += 1
                        } else {
                            errorCount += 1
                        }
                    } catch {
                        errorCount += 1
                    }
                }
                successMessage = "Removed interests from \(successCount) posts. \(errorCount) failed."
                
            case .reassignPosts:
                guard !newUserId.isEmpty else {
                    errorMessage = "Please enter a user ID"
                    showError = true
                    isProcessing = false
                    return
                }
                
                // Verify user exists
                let profile = try? await profileService.getUserProfile(userId: newUserId)
                guard profile != nil else {
                    errorMessage = "User ID not found"
                    showError = true
                    isProcessing = false
                    return
                }
                
                for post in selectedPosts {
                    do {
                        try await db.collection("posts").document(post.id).updateData([
                            "userId": newUserId,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                        successCount += 1
                    } catch {
                        errorCount += 1
                    }
                }
                successMessage = "Reassigned \(successCount) posts. \(errorCount) failed."
                
            case .deletePosts:
                for post in selectedPosts {
                    do {
                        try await db.collection("posts").document(post.id).delete()
                        successCount += 1
                    } catch {
                        errorCount += 1
                    }
                }
                successMessage = "Deleted \(successCount) posts. \(errorCount) failed."
            }
            
            // Reload posts to reflect changes
            await loadPosts()
            selectedPostIds.removeAll()
            
        } catch {
            errorMessage = "Operation failed: \(error.localizedDescription)"
            showError = true
        }
        
        isProcessing = false
        if successMessage != nil {
            showSuccess = true
        }
    }
}

#Preview {
    BulkEditPostView()
        .environmentObject(AuthViewModel())
}

