//
//  PostTaggingView.swift
//  OraBeta
//
//  DEPRECATED: This file is no longer used since we migrated from tags to interests.
//  Keeping as a placeholder to avoid breaking references.
//

import SwiftUI

/// DEPRECATED: Tags have been replaced with the interests system.
/// This View is no longer functional and should not be used.
struct PostTaggingView: View {
    @StateObject private var viewModel = PostTaggingViewModel()
    @Environment(\.dismiss) var dismiss
    var onComplete: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Feature Deprecated")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("The tag system has been replaced with the interests system. This feature is no longer available.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    dismiss()
                    onComplete?()
                }) {
                    Text("Close")
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
