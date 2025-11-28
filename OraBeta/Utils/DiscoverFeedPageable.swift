//
//  DiscoverFeedPageable.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore

/// Pageable implementation for the discover feed
struct DiscoverFeedPageable: Pageable {
    typealias Value = Post
    
    private let feedService: FeedService
    private let userId: String
    private let strategy: RankingStrategy
    private let applyRanking: Bool
    
    init(
        feedService: FeedService,
        userId: String,
        strategy: RankingStrategy = HybridStrategy(),
        applyRanking: Bool = true
    ) {
        self.feedService = feedService
        self.userId = userId
        self.strategy = strategy
        self.applyRanking = applyRanking
    }
    
    func loadPage(pageInfo: PageInfo?, size: Int) async throws -> (values: [Post], pageInfo: PageInfo) {
        // Extract cursor from pageInfo
        let lastDocument = pageInfo?.endCursor
        
        // Load posts from feed service
        let (posts, newLastDocument) = try await feedService.getDiscoverFeed(
            userId: userId,
            limit: size,
            strategy: strategy,
            lastDocument: lastDocument,
            applyRanking: applyRanking
        )
        
        // Determine if there are more pages
        let hasNextPage = newLastDocument != nil && posts.count >= size
        
        // Create new page info
        let newPageInfo = PageInfo.withCursor(newLastDocument, hasNextPage: hasNextPage)
        
        return (posts, newPageInfo)
    }
}






