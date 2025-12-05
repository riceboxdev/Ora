//
//  PostTaggingViewModel.swift
//  OraBeta
//
//  DEPRECATED: This file is no longer used since we migrated from tags to interests.
//  Keeping as a placeholder to avoid breaking references.
//

import Foundation
import Combine

/// DEPRECATED: Tags have been replaced with the interests system.
/// This ViewModel is no longer functional and should not be used.
@MainActor
class PostTaggingViewModel: ObservableObject {
    @Published var currentPost: Post?
    @Published var currentPostIndex: Int = 0
    @Published var totalPosts: Int = 0
    @Published var selectedTags: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String? = "Tags system is deprecated. Please use interests instead."
    @Published var isComplete = false
    
    /// DEPRECATED: No longer functional
    func loadUntaggedPosts() async {
        errorMessage = "Tags system is deprecated. Please use the interests system instead."
    }
    
    /// DEPRECATED: No longer functional
    func saveTagsAndContinue() async {
        errorMessage = "Tags system is deprecated. Please use the interests system instead."
    }
    
    /// DEPRECATED: No longer functional
    func getCurrentPostId() -> String? {
        return nil
    }
    
    /// DEPRECATED: No longer functional
    func hasUntaggedPosts() async -> Bool {
        return false
    }
}
