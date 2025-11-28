//
//  PaginationFooter.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import SwiftUI

/// A reusable footer component for pagination
struct PaginationFooter<ViewModel: PaginatableViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoadingMore {
                CenteredLoadingIndicator()
                    .padding(.vertical)
            } else if !viewModel.hasMore && !viewModel.posts.isEmpty {
                Text("No more posts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .onAppear {
                        Logger.info("📍 'No more posts' message appeared", service: "PaginationFooter")
                    }
            } else if viewModel.hasMore && !viewModel.isLoading {
                // Invisible footer trigger
                Color.clear
                    .frame(height: 50)
                    .onAppear {
                        Logger.info("👇 Footer trigger appeared", service: "PaginationFooter")
                        viewModel.loadMoreTriggered()
                    }
            }
        }
    }
}
