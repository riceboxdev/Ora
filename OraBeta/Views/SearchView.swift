//
//  SearchView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import MasonryStack

struct SearchView: View {
    @State private var searchText = ""
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var currentQueryID: String? // For click tracking
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Search")
                .searchable(text: $searchText, prompt: "Search posts, tags, users...")
                .onChange(of: searchText) { oldValue, newValue in
                    // Debounce search - cancel previous task
                    searchTask?.cancel()
                    
                    // Clear results if search is empty
                    if newValue.isEmpty {
                        posts = []
                        currentQueryID = nil
                        return
                    }
                    
                    // Debounce: wait 300ms before searching
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                        
                        // Check if task was cancelled
                        guard !Task.isCancelled else { return }
                        
                        await search(query: newValue)
                    }
                }
                .onSubmit(of: .search) {
                    Task {
                        await search(query: searchText)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if posts.isEmpty && !searchText.isEmpty {
            VStack {
                Text("No results found")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if posts.isEmpty {
            VStack {
                Text("Search for posts, tags, or users")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                PostGrid(posts: posts, queryID: currentQueryID)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func search(query: String) async {
        guard !query.isEmpty else {
            posts = []
            currentQueryID = nil
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await AlgoliaSearchService.shared.searchPosts(query: query)
            posts = result.posts
            currentQueryID = result.queryID
            
            print("✅ SearchView: Found \(result.nbHits) total results, showing \(posts.count) posts")
        } catch {
            print("❌ SearchView: Search failed: \(error.localizedDescription)")
            posts = []
            currentQueryID = nil
        }
    }
}

#Preview {
    SearchView()
}

