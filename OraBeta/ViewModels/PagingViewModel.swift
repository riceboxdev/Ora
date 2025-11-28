//
//  PagingViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import SwiftUI
import Combine

/// Generic view model for paginated data
/// Inspired by the Whatnot Engineering article: https://medium.com/whatnot-engineering/the-next-page-8950875d927a
@MainActor
class PagingViewModel<Source: Pageable>: ObservableObject {
    // MARK: - Published Properties
    
    @Published var items: [Source.Value] = []
    @Published var state: PagingState = .idle
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let source: Source
    private let pageSize: Int
    private let threshold: Int
    private var pageInfo: PageInfo?
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(source: Source, pageSize: Int = 20, threshold: Int = 3) {
        self.source = source
        self.pageSize = pageSize
        self.threshold = threshold
        self.pageInfo = PageInfo.initial()
    }
    
    // MARK: - Public Methods
    
    /// Load the first page
    func loadFirstPage() async {
        guard state != .loadingFirstPage else { return }
        
        state = .loadingFirstPage
        errorMessage = nil
        
        do {
            let (values, newPageInfo) = try await source.loadPage(pageInfo: nil, size: pageSize)
            items = values
            pageInfo = newPageInfo
            state = .idle
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }
    
    /// Called when an item appears in the view
    /// Triggers loading more items if threshold is reached
    func onItemAppear(_ item: Source.Value) {
        // Early returns to prevent unnecessary loads
        guard let pageInfo = pageInfo, pageInfo.hasNextPage else {
            return // No more pages available
        }
        
        guard state != .loadingFirstPage && state != .loadingNextPage else {
            return // Already loading
        }
        
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return // Item not found in array
        }
        
        // Check if we've reached the threshold
        let distanceFromEnd = items.count - index - 1
        guard distanceFromEnd <= threshold else {
            return // Not close enough to the end
        }
        
        // All requirements met - load more items
        loadMoreItems()
    }
    
    /// Load more items (next page)
    private func loadMoreItems() {
        // Cancel any existing task
        currentTask?.cancel()
        
        // Create new task
        currentTask = Task {
            guard let pageInfo = pageInfo, pageInfo.hasNextPage else {
                return
            }
            
            state = .loadingNextPage
            
            do {
                let (newValues, newPageInfo) = try await source.loadPage(
                    pageInfo: pageInfo,
                    size: pageSize
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Append new items to existing ones
                items.append(contentsOf: newValues)
                self.pageInfo = newPageInfo
                state = .idle
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                state = .error
            }
        }
    }
    
    /// Refresh the feed (reload from beginning)
    func refresh() async {
        pageInfo = PageInfo.initial()
        items = []
        await loadFirstPage()
    }
    
    /// Reset the view model
    func reset() {
        currentTask?.cancel()
        currentTask = nil
        items = []
        pageInfo = PageInfo.initial()
        state = .idle
        errorMessage = nil
    }
}

// MARK: - PagingState

enum PagingState {
    case idle
    case loadingFirstPage
    case loadingNextPage
    case error
}






