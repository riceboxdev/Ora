//
//  PaginationDebugOverlay.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

/// Debug overlay to visualize pagination state
/// Add this to your view for testing: `.overlay(PaginationDebugOverlay(viewModel: viewModel))`
struct PaginationDebugOverlay: View {
    @ObservedObject var viewModel: DiscoverFeedViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 Pagination Debug")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.5))
            
            HStack {
                Text("Posts:")
                Spacer()
                Text("\(viewModel.posts.count)")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .font(.caption)
            
            HStack {
                Text("Loading:")
                Spacer()
                Text(viewModel.isLoading ? "🔄 Initial" : viewModel.isLoadingMore ? "⏳ More" : "✅ Idle")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .font(.caption)
            
            HStack {
                Text("Has More:")
                Spacer()
                Text(viewModel.hasMore ? "✅ Yes" : "❌ No")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .font(.caption)
            
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption2)
                    .lineLimit(2)
            }
            
            Text("Threshold: Last 3 posts")
                .foregroundColor(.white.opacity(0.7))
                .font(.caption2)
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding()
        .frame(maxWidth: 200, maxHeight: 200, alignment: .topLeading)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        PaginationDebugOverlay(viewModel: DiscoverFeedViewModel())
    }
}






