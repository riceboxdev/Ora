//
//  PostClassificationService.swift
//  OraBeta
//
//  Service for classifying posts to interests
//  Implements Pin2Interest classification system with candidate generation + ranking
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class PostClassificationService {
    private let db = Firestore.firestore()
    private let classificationsCollection = "post_classifications"
    private let interestService: InterestTaxonomyService
    
    static let shared = PostClassificationService()
    
    init(interestService: InterestTaxonomyService = .shared) {
        self.interestService = interestService
    }
    
    // MARK: - Public Classification Methods
    
    /// Classify a post to interests
    func classifyPost(_ post: Post) async throws -> PostInterestClassification {
        let candidates = try await generateCandidates(post: post)
        let classifications = try await rankCandidates(candidates, post: post)
        
        let classification = PostInterestClassification(
            postId: post.id,
            classifications: classifications
        )
        
        try await db.collection(classificationsCollection).document(post.id).setData(classification.toFirestoreData())
        
        return classification
    }
    
    /// Get existing classification for a post
    func getClassification(postId: String) async throws -> PostInterestClassification? {
        let document = try await db.collection(classificationsCollection).document(postId).getDocument()
        return try PostInterestClassification.from(document: document)
    }
    
    /// Suggest interests during post creation
    func suggestInterestsForPost(
        caption: String? = nil,
        tags: [String]? = nil,
        boardId: String? = nil
    ) async throws -> [PostInterestClassification.Classification] {
        let candidates = try await generateCandidatesFromInput(
            caption: caption,
            boardId: boardId
        )
        
        let mockPost = Post(
            activityId: "temp",
            userId: "temp",
            imageUrl: ""
        )
        
        return try await rankCandidates(candidates, post: mockPost)
    }
    
    // MARK: - Stage 1: Candidate Generation
    
    /// Generate candidate interests from post data
    private func generateCandidates(post: Post) async throws -> [InterestCandidate] {
        return try await generateCandidatesFromInput(
            caption: post.caption,
            boardId: nil
        )
    }
    
    /// Generate candidates from input data (shared logic)
    private func generateCandidatesFromInput(
        caption: String?,
        boardId: String?
    ) async throws -> [InterestCandidate] {
        var candidates: [String: InterestCandidate] = [:]
        let allInterests = try await interestService.getAllInterests()
        
        var sources: [String: [String]] = [:]
        
        // 1. Extract keywords from caption
        if let caption = caption {
            let keywords = extractKeywords(from: caption)
            sources["caption"] = keywords
        }
        
       
        
        // 3. Match keywords to interest keywords/synonyms (lexical expansion)
        for interest in allInterests {
            var matchScore = 0.0
            var matchedSources: Set<String> = []
            
            if let captionKeywords = sources["caption"] {
                for keyword in captionKeywords {
                    let keywordLower = keyword.lowercased()
                    
                    if interest.keywords.contains(where: { $0.lowercased() == keywordLower }) {
                        matchScore += 1.0
                        matchedSources.insert("caption")
                    }
                    
                    if interest.synonyms.contains(where: { $0.lowercased() == keywordLower }) {
                        matchScore += 0.8
                        matchedSources.insert("caption")
                    }
                }
            }
            
            if let tags = sources["tags"] {
                for tag in tags {
                    let tagLower = tag.lowercased()
                    
                    if interest.keywords.contains(where: { $0.lowercased() == tagLower }) {
                        matchScore += 0.9
                        matchedSources.insert("tags")
                    }
                    
                    if interest.synonyms.contains(where: { $0.lowercased() == tagLower }) {
                        matchScore += 0.7
                        matchedSources.insert("tags")
                    }
                }
            }
            
            if matchScore > 0 {
                candidates[interest.id] = InterestCandidate(
                    interestId: interest.id,
                    interestName: interest.name,
                    interestLevel: interest.level,
                    matchScore: matchScore,
                    sources: Array(matchedSources)
                )
            }
        }
        
        return Array(candidates.values).sorted { $0.matchScore > $1.matchScore }.prefix(100).map { $0 }
    }
    
    // MARK: - Stage 2: Ranking/Scoring
    
    /// Rank and score candidate interests
    private func rankCandidates(
        _ candidates: [InterestCandidate],
        post: Post
    ) async throws -> [PostInterestClassification.Classification] {
        let topCandidates = Array(candidates.prefix(20))
        
        var classifications: [PostInterestClassification.Classification] = []
        
        for candidate in topCandidates {
            let interest = try? await interestService.getInterest(id: candidate.interestId)
            
            var signals: [PostInterestClassification.Classification.ClassificationSignal] = []
            
            if let interest = interest {
                let confidence = calculateConfidence(
                    candidate: candidate,
                    interest: interest,
                    post: post,
                    signals: &signals
                )
                
                if confidence > 0.3 {
                    let classification = PostInterestClassification.Classification(
                        interestId: candidate.interestId,
                        interestName: candidate.interestName,
                        interestLevel: candidate.interestLevel,
                        confidence: confidence,
                        signals: signals
                    )
                    classifications.append(classification)
                }
            }
        }
        
        return classifications
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0 }
    }
    
    /// Calculate confidence score for a candidate
    private func calculateConfidence(
        candidate: InterestCandidate,
        interest: Interest,
        post: Post,
        signals: inout [PostInterestClassification.Classification.ClassificationSignal]
    ) -> Double {
        var confidence = 0.0
        
        let keywordMatchScore = min(candidate.matchScore / 3.0, 1.0)
        confidence += keywordMatchScore * 0.35
        
        if candidate.sources.contains("tags") {
            signals.append(.userTagged)
            confidence += 0.15
        } else {
            signals.append(.captionMatch)
        }
        
        if !interest.keywords.isEmpty {
            signals.append(.tfIdf)
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Helper Methods
    
    /// Extract keywords from text
    private func extractKeywords(from text: String) -> [String] {
        let words = text
            .lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 && !isStopword($0) }
        
        return Array(Set(words))
    }
    
    /// Check if a word is a common stopword
    private func isStopword(_ word: String) -> Bool {
        let stopwords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
            "that", "this", "these", "those", "which", "who", "what", "when", "where",
            "why", "how", "it", "its", "if", "else", "then", "as", "about", "up",
            "just", "so", "out", "own", "than", "too", "very", "can", "will", "do"
        ])
        return stopwords.contains(word)
    }
}

// MARK: - Supporting Types

struct InterestCandidate {
    let interestId: String
    let interestName: String
    let interestLevel: Int
    let matchScore: Double
    let sources: [String]
}
