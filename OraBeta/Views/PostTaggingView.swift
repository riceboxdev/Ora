//
//  PostTaggingView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import Kingfisher

struct PostTaggingView: View {
    @StateObject private var viewModel = PostTaggingViewModel()
    @Environment(\.dismiss) var dismiss
    var onComplete: (() -> Void)?
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var isFocused: Bool = false
    @State private var imageHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            } else if viewModel.isComplete {
                CompletionView {
                    dismiss()
                    onComplete?()
                }
            } else if let post = viewModel.currentPost {
                ScrollView {
                    VStack(spacing: 0) {
                        // Progress indicator with close button
                        ZStack {
                            VStack(spacing: 8) {
                                ProgressView(value: Double(viewModel.currentPostIndex), total: Double(viewModel.totalPosts))
                                    .tint(.white)
                                    .padding(.horizontal)
                                
                                Text("Post \(viewModel.currentPostIndex + 1) of \(viewModel.totalPosts)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Add tags to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.vertical, 20)
                            
                            // Close button in top trailing corner
                            HStack {
                                Spacer()
                                VStack {
                                    Button(action: {
                                        dismiss()
                                        onComplete?()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.trailing, 16)
                                    .padding(.top, 8)
                                    Spacer()
                                }
                            }
                        }
                        .background(Color.black.opacity(0.5))
                        
                        // Post image - shrinks when text field is focused
                        KFImage(URL(string: post.imageUrl))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: isFocused ? 120 : imageHeight)
                            .animation(.easeInOut(duration: 0.3), value: isFocused)
                        
                        // Tag input section
                        VStack(spacing: 16) {
                            TagAutocompleteView(
                                selectedTags: $viewModel.selectedTags,
                                semanticLabels: nil,
                                postId: viewModel.getCurrentPostId(),
                                minTags: 1,
                                maxTags: 5,
                                isFocused: $isFocused
                            )
                            .onChange(of: isTextFieldFocused) { oldValue, newValue in
                                isFocused = newValue
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            
                            // Save button
                            Button(action: {
                                // Dismiss keyboard
                                isTextFieldFocused = false
                                isFocused = false
                                Task {
                                    await viewModel.saveTagsAndContinue()
                                }
                            }) {
                                HStack {
                                    if viewModel.isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Save & Continue")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.selectedTags.isEmpty ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.selectedTags.isEmpty || viewModel.isSaving)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(.systemBackground))
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    isTextFieldFocused = false
                    isFocused = false
                }
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .task {
            await viewModel.loadUntaggedPosts()
        }
    }
}

struct CompletionView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("All Done!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("All your posts have been tagged. You can now use the app normally.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                onDismiss()
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
