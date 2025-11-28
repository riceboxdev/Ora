//
//  PaginatableViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation

/// Protocol for ViewModels that support pagination
@MainActor
protocol PaginatableViewModel: ObservableObject {
    var isLoadingMore: Bool { get set }
    var hasMore: Bool { get }
    var isLoading: Bool { get }
    var posts: [Post] { get }
    
    /// Trigger load more from footer (explicit trigger)
    func loadMoreTriggered()
}
