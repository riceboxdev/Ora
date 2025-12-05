//
//  InterestFeedViewModel.swift
//  OraBeta
//
//  ViewModel for interest-filtered feed
//  Loads and manages posts containing a specific interest ID
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class InterestFeedViewModel: ObservableObject, PaginatableViewModel {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var errorMessage: String?
    @Published var isFollowing: Bool = false
    @Published var isLoadingFollow: Bool = false
    @Published var isCheckingFollowStatus: Bool = true
    
    // MARK: - Properties
    let interest: TrendingInterest
    let pageSize: Int = 20
    
    private let db = Firestore.firestore()
    private let interestFollowService = InterestFollowService.shared
    private var lastDocument: QueryDocumentSnapshot?
    
    // MARK: - Initialization
    
    init(interest: TrendingInterest) {
        self.interest = interest
    }
    
    // MARK: - Public Methods
    
    /// Load posts for this interest
    func loadPosts() async {
        print("🔄 InterestFeedViewModel: Loading posts for interest '\(interest.name)'")
        
        // Reset pagination
        lastDocument = nil
        hasMore = true
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Query posts where interestIds array contains this interest ID
            let query = db.collection("posts")
                .whereField("interestIds", arrayContains: interest.id)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            // Convert documents to Post objects
            var newPosts: [Post] = []
            for document in snapshot.documents {
                if let post = await Post.from(
                    firestoreData: document.data(),
                    documentId: document.documentID,
                    profiles: [:]
                ) {
                    newPosts.append(post)
                }
            }
            
            posts = newPosts
            lastDocument = snapshot.documents.last
            hasMore = newPosts.count >= pageSize
            
            print("✅ InterestFeedViewModel: Loaded \(newPosts.count) posts for interest '\(interest.name)'")
            
            // Check follow status
            await checkFollowStatus()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ InterestFeedViewModel: Failed to load posts: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Load more posts (pagination)
    func loadMorePosts() async {
        guard hasMore, !isLoadingMore, let lastDoc = lastDocument else {
            return
        }
        
        print("🔄 InterestFeedViewModel: Loading more posts for interest '\(interest.name)'")
        
        isLoadingMore = true
        
        do {
            let query = db.collection("posts")
                .whereField("interestIds", arrayContains: interest.id)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            var newPosts: [Post] = []
            for document in snapshot.documents {
                if let post = await Post.from(
                    firestoreData: document.data(),
                    documentId: document.documentID,
                    profiles: [:]
                ) {
                    newPosts.append(post)
                }
            }
            
            posts.append(contentsOf: newPosts)
            lastDocument = snapshot.documents.last
            hasMore = newPosts.count >= pageSize
            
            print("✅ InterestFeedViewModel: Loaded \(newPosts.count) more posts")
        } catch {
            print("❌ InterestFeedViewModel: Failed to load more posts: \(error.localizedDescription)")
            hasMore = false
        }
        
        isLoadingMore = false
    }
    
  /// Trigger load more from footer
    func loadMoreTriggered() {
        guard !isLoadingMore, hasMore, !isLoading else {
            return
        }
        
        isLoadingMore = true
        
        Task {
            await loadMorePosts()
        }
    }
    
    // MARK: - Follow Methods
    
    private func checkFollowStatus() async {
        isCheckingFollowStatus = true
        do {
            isFollowing = try await interestFollowService.isFollowingInterest(
                interestId: interest.id
            )
        } catch {
            print("❌ InterestFeedViewModel: Failed to check follow status: \(error.localizedDescription)")
            isFollowing = false
        }
        isCheckingFollowStatus = false
    }
    
    func toggleFollow() async {
        isLoadingFollow = true
        defer { isLoadingFollow = false }
        
        do {
            if isFollowing {
                try await interestFollowService.unfollowInterest(
                    interestId: interest.id
                )
                isFollowing = false
            } else {
                try await interestFollowService.followInterest(
                    interestId: interest.id
                )
                isFollowing = true
            }
        } catch {
            print("❌ InterestFeedViewModel: Failed to toggle follow: \(error.localizedDescription)")
        }
    }
}
