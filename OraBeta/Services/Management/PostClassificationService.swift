//
//  PostClassificationService.swift
//  OraBeta
//
//  Service for classifying posts to interests (Pin2Interest implementation)
//  Based on Pinterest's 2-stage P2I classification system
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class PostClassificationService {
    private let db = Firestore.firestore()
    private let classificationsCollection = "post_classifications"
    
    static let shared = PostClassificationService()
    
    // Classification parameters (tunable)
    private let candidateLimit = 50             // Max candidates to generate
    private let minConfidence = 0.5             // Minimum confidence to include
    private let topResultsLimit = 5             // Max classifications to return
    
    private init() {}
    
    // MARK: - Main Classification
    
    /// Classify a post to interests (2-stage process)
    /// - Parameter post: Post to classify
    /// - Returns: Classification result
    func classifyPost(_ post: Post) async throws -> PostInterestClassification {
        Logger.info("🔍 Starting classification for post: \(post.id)", service: "PostClassificationService")
        
        // STAGE 1: Candidate Generation
        let candidates = try await generateCandidates(post: post)
        Logger.info("📊 Generated \(candidates.count) candidates", service: "PostClassificationService")
        
        // STAGE 2: Ranking/Scoring
        let classifications = try await rankCandidates(candidates, post: post)
        Logger.info("✅ Ranked to \(classifications.count) classifications", service: "PostClassificationService")
        
        let result = PostInterestClassification(
            postId: post.id,
            classifications: classifications
        )
        
        // Store in Firestore
        try await saveClassification(result)
        
        return result
    }
    
    /// Suggest interests during post creation (before post exists)
    /// - Parameters:
    ///   - caption: Post caption
    ///   - tags: User-provided tags
    ///   - boardId: Optional board ID where post will be saved
    /// - Returns: Suggested classifications
    func suggestInterestsForPost(
        caption: String?,
        tags: [String]?,
        boardId: String? = nil
    ) async throws -> [PostInterestClassification.Classification] {
        Logger.info("💡 Suggesting interests for new post", service: "PostClassificationService")
        
        // Create temporary post for classification
        let tempPost = Post(
            activityId: "temp",
            userId: Auth.auth().currentUser?.uid ?? "",
            imageUrl: "",
            caption: caption,
            tags: tags
        )
        
        let candidates = try await generateCandidates(post: tempPost, boardId: boardId)
        let classifications = try await rankCandidates(candidates, post: tempPost)
        
        return classifications
    }
    
    // MARK: - Stage 1: Candidate Generation
    
    /// Generate interest candidates for a post
    /// Based on Pinterest's lexical expansion and matching approach
    private func generateCandidates(post: Post, boardId: String? = nil) async throws -> [InterestCandidate] {
        var candidates: [InterestCandidate] = []
        var seenInterestIds = Set<String>()
        
        // Extract keywords from post
        let keywords = extractKeywords(from: post)
        
        // Fetch all active interests (uses cache)
        let allInterests = try await InterestTaxonomyService.shared.getInterestTree()
        
        // 1. Match against user-provided tags (highest priority)
        if let userTags = post.tags {
            for tag in userTags {
                let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                for interest in allInterests {
                    if seenInterestIds.contains(interest.id) { continue }
                    
                    // Exact match on name
                    if interest.name == normalizedTag {
                        candidates.append(InterestCandidate(
                            interestId: interest.id,
                            interestName: interest.displayName,
                            interestLevel: interest.level,
                            matchScore: 1.0,
                            signals: [.userProvidedTag]
                        ))
                        seenInterestIds.insert(interest.id)
                    }
                    
                    // Match in keywords
                    else if interest.keywords.contains(where: { $0.lowercased() == normalizedTag }) {
                        candidates.append(InterestCandidate(
                            interestId: interest.id,
                            interestName: interest.displayName,
                            interestLevel: interest.level,
                            matchScore: 0.9,
                            signals: [.userProvidedTag]
                        ))
                        seenInterestIds.insert(interest.id)
                    }
                    
                    // Match in synonyms
                    else if interest.synonyms.contains(where: { $0.lowercased() == normalizedTag }) {
                        candidates.append(InterestCandidate(
                            interestId: interest.id,
                            interestName: interest.displayName,
                            interestLevel: interest.level,
                            matchScore: 0.85,
                            signals: [.userProvidedTag]
                        ))
                        seenInterestIds.insert(interest.id)
                    }
                }
            }
        }
        
        // 2. Match against caption keywords
        for keyword in keywords {
            for interest in allInterests {
                if seenInterestIds.contains(interest.id) { continue }
                
                // Check if keyword matches interest name, keywords, or synonyms
                let normalizedKeyword = keyword.lowercased()
                
                if interest.name.contains(normalizedKeyword) ||
                   interest.keywords.contains(where: { $0.lowercased().contains(normalizedKeyword) }) ||
                   interest.synonyms.contains(where: { $0.lowercased().contains(normalizedKeyword) }) {
                    
                    candidates.append(InterestCandidate(
                        interestId: interest.id,
                        interestName: interest.displayName,
                        interestLevel: interest.level,
                        matchScore: 0.7,
                        signals: [.captionMatch]
                    ))
                    seenInterestIds.insert(interest.id)
                }
            }
        }
        
        // 3. Board context (if available) - Future implementation
        // This would analyze the board name and get interests from it
        
        // 4. Similar posts - Future implementation
        // Find posts with similar captions/tags and use their classifications
        
        // Limit candidates
        return Array(candidates.prefix(candidateLimit))
    }
    
    // MARK: - Stage 2: Ranking
    
    /// Rank candidates and assign final confidence scores
    /// Based on Pinterest's GBDT ranking approach (simplified version)
    private func rankCandidates(
        _ candidates: [InterestCandidate],
        post: Post
    ) async throws -> [PostInterestClassification.Classification] {
        var scoredCandidates: [(candidate: InterestCandidate, confidence: Double)] = []
        
        for candidate in candidates {
            let confidence = calculateConfidence(candidate: candidate, post: post)
            scoredCandidates.append((candidate, confidence))
        }
        
        // Sort by confidence descending
        scoredCandidates.sort { $0.confidence > $1.confidence }
        
        // Filter by minimum confidence and limit results
        let topCandidates = scoredCandidates
            .filter { $0.confidence >= minConfidence }
            .prefix(topResultsLimit)
        
        // Convert to Classifications
        return topCandidates.map { item in
            item.candidate.toClassification(confidence: item.confidence)
        }
    }
    
    /// Calculate final confidence score for a candidate
    /// This is a simplified version of Pinterest's GBDT model
    private func calculateConfidence(candidate: InterestCandidate, post: Post) -> Double {
        var confidence = candidate.matchScore
        
        // Signal weighting (based on Pinterest's approach)
        let signalWeights: [PostInterestClassification.Classification.ClassificationSignal: Double] = [
            .userTagged: 0.20,          // User explicitly selected
            .userProvidedTag: 0.20,     // User typed this tag
            .captionMatch: 0.35,        // Found in caption
            .boardName: 0.25,           // Matched board name
            .similarPosts: 0.10,        // Similar posts have this
            .userBehavior: 0.10,        // Users who engage have this
            .visualSimilarity: 0.10,    // Future: image similarity
            .tfIdf: 0.10                // Future: TF-IDF score
        ]
        
        // Apply signal weights
        var totalWeight = 0.0
        for signal in candidate.signals {
            if let weight = signalWeights[signal] {
                totalWeight += weight
            }
        }
        
        // Combine match score with signal weights
        confidence = (confidence * 0.50) + (totalWeight * 0.50)
        
        // Boost for specific interest levels (prefer more specific)
        let levelBoost = Double(candidate.interestLevel) * 0.05  // Deeper = higher confidence
        confidence = min(confidence + levelBoost, 1.0)
        
        // Future: Add user history boost (if user frequently engages with this interest)
        // Future: Add post quality signals
        
        return confidence
    }
    
    // MARK: - Helper Methods
    
    /// Extract keywords from post caption and tags
    private func extractKeywords(from post: Post) -> [String] {
        var keywords: [String] = []
        
        // Extract from caption
        if let caption = post.caption {
            // Simple tokenization (split by spaces, remove punctuation)
            let words = caption
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { word in
                    word.trimmingCharacters(in: .punctuationCharacters)
                }
                .filter { !$0.isEmpty && $0.count > 2 }  // Filter short words
            
            keywords.append(contentsOf: words)
        }
        
        // Include user tags
        if let tags = post.tags {
            keywords.append(contentsOf: tags)
        }
        
        // Remove duplicates
        return Array(Set(keywords))
    }
    
    // MARK: - Storage
    
    /// Save classification to Firestore
    private func saveClassification(_ classification: PostInterestClassification) async throws {
        let data = classification.toFirestoreData()
        try await db.collection(classificationsCollection)
            .document(classification.postId)
            .setData(data)
        
        Logger.info("💾 Saved classification for post: \(classification.postId)", service: "PostClassificationService")
    }
    
    /// Get classification for a post
    func getClassification(postId: String) async throws -> PostInterestClassification? {
        let doc = try await db.collection(classificationsCollection)
            .document(postId)
            .getDocument()
        
        return try PostInterestClassification.from(document: doc)
    }
    
    /// Update post's interest fields based on classification
    func updatePostInterestFields(postId: String, classification: PostInterestClassification) async throws {
        let interestIds = classification.interestIdsByConfidence
        let primaryInterestId = classification.primaryInterest?.interestId
        
        // Create interest scores map
        var interestScores: [String: Double] = [:]
        for class in classification.classifications {
            interestScores[class.interestId] = class.confidence
        }
        
        // Update post document
        try await db.collection("posts").document(postId).updateData([
            "interestIds": interestIds,
            "primaryInterestId": primaryInterestId as Any,
            "interestScores": interestScores
        ])
        
        // Update interest post counts
        for interestId in interestIds {
            try await InterestTaxonomyService.shared.incrementPostCount(interestId: interestId)
        }
        
        Logger.info("✅ Updated post interest fields: \(postId)", service: "PostClassificationService")
    }
}
