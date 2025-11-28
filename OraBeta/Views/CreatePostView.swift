//
//  CreatePostView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

// Data for each individual image post
struct ImagePostData: Identifiable {
    let id = UUID()
    var image: UIImage
    var caption: String = ""
    var tags: Set<String> = []
}

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @EnvironmentObject var authViewModel: AuthViewModel
    private let queueService = UploadQueueService.shared
    
    // Multi-image support (up to 10 for all users)
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var imagePosts: [ImagePostData] = []
    
    // UI state
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var selectedPostIndex: Int = 0 // Track which image is being edited
    @State private var showTagSheet = false
    
    // Processing progress
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var errorCount: Int = 0
    @State private var showProgress = false
    @State private var enqueuedCount: Int = 0
    
    let availableTags = ["Nature", "Abstract", "Space", "Animals", "Architecture", "Food", "Travel", "Art", "Minimalist", "Vintage", "Modern", "Classic", "Colorful", "Black & White", "Landscape", "Portrait"]
    
    init() {
        print("🏗️ CreatePostView: View initialized")
    }
    
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                if imagePosts.isEmpty {
                    gridLines()
                }
                
                // Scrollable content (form)
                mainContentView
                    .navigationTitle("New Post\(imagePosts.count > 1 ? "s" : "")")
                    .navigationBarTitleDisplayMode(.inline)
                
                // Floating thumbnails
                if !imagePosts.isEmpty {
                    thumbnailFloatingBar
                }
                
                if imagePosts.isEmpty {
                    VStack {
                        Spacer()
                        emptyStatePhotoPicker
                            .padding(.horizontal)
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if !isProcessing {
                            dismiss()
                        }
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            await uploadImages()
                        }
                    }
                    .disabled(imagePosts.isEmpty || isLoading || !allImagesHaveTags)
                }
            }
            .task(id: photoPickerItems) {
                await loadSelectedImages()
            }
            .alert("Post Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailFloatingBar: some View {
        VStack(spacing: 0) {
          
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(imagePosts.enumerated()), id: \.offset) { index, post in
                        thumbnailButton(post: post, index: index)
                    }
                    
                    // Add more photos button
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            Image("plus.solid")
                                .font(.title)
                        }
                        .frame(width: 50, height: 80)
                        .background(.clear)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 20,
                    bottomTrailingRadius: 20
                )
            )
            Divider()
        }
        .background(Color("oraquaternary"))
//        .shadow(radius: 10)
    }
    
    @ViewBuilder
    private func thumbnailButton(post: ImagePostData, index: Int) -> some View {
        let cornerRadius: CGFloat = 12
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPostIndex = index
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: post.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        Color.whiteui.opacity(
                            selectedPostIndex == index ? 0 : 0.35
                        )
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                   
                
//                // Status badge
//                HStack(spacing: 2) {
//                    if !post.tags.isEmpty {
//                        Image(systemName: "checkmark.circle.fill")
//                            .font(.caption2)
//                            .foregroundColor(.green)
//                    }
//                    Text("\(post.tags.count)")
//                        .font(.caption2)
//                        .foregroundColor(.white)
//                }
//                .padding(.horizontal, 4)
//                .padding(.vertical, 2)
//                .background(Color.black.opacity(0.7))
//                .cornerRadius(6)
//                .padding(4)
            }
            
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        .scaleEffect(selectedPostIndex == index ? 1.1 : 1)
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if imagePosts.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                // Add padding for floating thumbnails
                Color.clear.frame(height: 104)
                
                // Inline form for selected image
                if selectedPostIndex < imagePosts.count {
                    inlineEditForm
                }
                
                if showProgress {
                    progressSection
                        .padding(.vertical)
                }
            }
        }
    }
    
    @ViewBuilder
    private var inlineEditForm: some View {
        List {
            // Image preview section
            Section {
                Image(uiImage: imagePosts[selectedPostIndex].image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxHeight: 300)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            
            // Caption section
            Section(
                header: Text("Caption")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                TextField("Write a caption...", text: $imagePosts[selectedPostIndex].caption, axis: .vertical)
                    .font(.creatoDisplayBody())
                    .lineLimit(3...6)
            }
            
            // Tags section
            Section(
                header: Text("Tags (Required: 1-5)")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if imagePosts[selectedPostIndex].tags.isEmpty {
                    Button {
                        showTagSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Tags")
                        }
                        .font(.creatoDisplayBody())
                        .foregroundColor(.accentColor)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(imagePosts[selectedPostIndex].tags), id: \.self) { tag in
                                TagChip(tag: tag, isSelected: true) {
                                    imagePosts[selectedPostIndex].tags.remove(tag)
                                }
                            }
                            
                            Button {
                                showTagSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .settingsListStyle()
        .sheet(isPresented: $showTagSheet) {
            NavigationView {
                VStack {
                    TagAutocompleteView(
                        selectedTags: $imagePosts[selectedPostIndex].tags,
                        semanticLabels: nil,
                        postId: nil,
                        minTags: 1,
                        maxTags: 5
                    )
                    .padding()
                    Spacer()
                }
                .navigationTitle("Edit Tags")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showTagSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    @ViewBuilder
    private var emptyStatePhotoPicker: some View {
        PhotosPicker(
            selection: $photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        ) {
            VStack(alignment: .center) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                VStack(alignment: .center, spacing: 4) {
                    Text("Select Photos")
                        .font(.headline)
                    Text("Up to 10 images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
    }
    
    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: processingProgress, total: 1.0)
                    .tint(.blue)
                
                HStack {
                    Text("Processed: \(processedCount)/\(totalCount)")
                        .font(.caption)
                    Spacer()
                    if errorCount > 0 {
                        Text("Errors: \(errorCount)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack {
                    Text("Enqueued: \(enqueuedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .background(.quaternary)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func gridLines() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        ).ignoresSafeArea()
    }
    
    func getSafeAreaTop()->CGFloat{
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        return (keyWindow?.safeAreaInsets.top ?? 0)
        
    }
    
    // Helper to check if all images have required tags
    private var allImagesHaveTags: Bool {
        imagePosts.allSatisfy { $0.tags.count >= 1 && $0.tags.count <= 5 }
    }
    
    // MARK: - Image Loading
    
    private func loadSelectedImages() async {
        imagePosts.removeAll()
        isLoading = true
        
        for item in photoPickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let postData = ImagePostData(image: image)
                imagePosts.append(postData)
            }
        }
        
        // Reset selection to first image when loading new images
        if !imagePosts.isEmpty {
            selectedPostIndex = 0
        }
        
        isLoading = false
    }
    
    // MARK: - Multi-Image Upload
    
    private func uploadImages() async {
        print("🚀 CreatePostView.uploadImages() called - Adding to upload queue")

        guard !imagePosts.isEmpty else {
            print("❌ CreatePostView: No images selected")
            errorMessage = "Please select at least one image"
            showErrorAlert = true
            return
        }

        guard authViewModel.currentUser?.uid != nil else {
            print("❌ CreatePostView: No user ID available")
            errorMessage = "User not authenticated"
            showErrorAlert = true
            return
        }
        
        // Validate all images have tags
        guard allImagesHaveTags else {
            errorMessage = "Please add 1-5 tags to each image"
            showErrorAlert = true
            return
        }

        print("✅ CreatePostView: Validation passed")
        print("   Images count: \(imagePosts.count)")

        // Process images
        isLoading = true
        totalCount = imagePosts.count
        processedCount = 0
        errorCount = 0
        showProgress = imagePosts.count > 1 // Only show progress for multiple images
        
        var payloads: [UploadPayload] = []
        
        for (index, postData) in imagePosts.enumerated() {
            print("📤 CreatePostView: Processing image \(index + 1)/\(imagePosts.count)...")
            
            guard let processed = await ImageProcessor.shared.processImage(postData.image) else {
                print("❌ CreatePostView: Failed to process image \(index + 1)")
                errorCount += 1
                continue
            }
            
            print("✅ CreatePostView: Image \(index + 1) processed successfully")
            
            // Create payload with per-image caption and tags
            let payload = UploadPayload(
                imageData: processed.fullImageData,
                thumbnailData: processed.thumbnailData,
                imageWidth: processed.width,
                imageHeight: processed.height,
                title: postData.caption.isEmpty ? nil : postData.caption,
                description: postData.caption.isEmpty ? nil : postData.caption,
                tags: Array(postData.tags),
                categories: Array(postData.tags)
            )
            
            payloads.append(payload)
            processedCount += 1
            
            if showProgress {
                processingProgress = Double(processedCount) / Double(totalCount)
            }
        }
        
        guard !payloads.isEmpty else {
            errorMessage = "Failed to process images. Please try again."
            showErrorAlert = true
            isLoading = false
            return
        }
        
        print("✅ CreatePostView: \(payloads.count) payloads created")
        
        // Enqueue all payloads at once
        await MainActor.run {
            queueService.enqueue(payloads)
        }
        
        isLoading = false
        print("✅ CreatePostView: \(payloads.count) post(s) added to upload queue")
        
        // Dismiss sheet - queue card will appear on home screen
        dismiss()
    }
}

#Preview {
    CreatePostView()
        .environmentObject(AuthViewModel())
        .previewAuthenticated()
}

// MARK: - Image Edit Sheet

struct ImageEditSheet: View {
    @Binding var post: ImagePostData
    @Environment(\.dismiss) var dismiss
    
    let availableTags = ["Nature", "Abstract", "Space", "Animals", "Architecture", "Food", "Travel", "Art", "Minimalist", "Vintage", "Modern", "Classic", "Colorful", "Black & White", "Landscape", "Portrait"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    Image(uiImage: post.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    
                    // Caption
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Caption")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Write a caption...", text: $post.caption, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding()
                            .background(.quaternary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags (Required: 1-5)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TagAutocompleteView(
                            selectedTags: $post.tags,
                            semanticLabels: nil,
                            postId: nil,
                            minTags: 1,
                            maxTags: 5
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Edit Post Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(post.tags.count < 1 || post.tags.count > 5)
                }
            }
        }
    }
}
