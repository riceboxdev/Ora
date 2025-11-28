//
//  ModerationRule.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation

/// Result of a moderation rule evaluation
struct ModerationResult {
    /// The moderation status to apply
    let status: ModerationStatus
    
    /// Optional reason for the decision
    let reason: String?
    
    /// Additional metadata about the decision
    let metadata: [String: String]?
    
    /// Whether to continue evaluating other rules
    /// Set to false if this rule makes a final decision
    let shouldContinueEvaluation: Bool
    
    init(
        status: ModerationStatus,
        reason: String? = nil,
        metadata: [String: String]? = nil,
        shouldContinueEvaluation: Bool = true
    ) {
        self.status = status
        self.reason = reason
        self.metadata = metadata
        self.shouldContinueEvaluation = shouldContinueEvaluation
    }
}

/// Protocol for implementing moderation rules
/// Rules are executed in priority order (highest first)
protocol ModerationRule {
    /// Name of the rule (for logging and audit trail)
    var name: String { get }
    
    /// Priority of the rule (higher runs first)
    /// Suggested ranges:
    /// - 100+: Critical security rules
    /// - 50-99: High priority automated rules
    /// - 10-49: Standard automated rules
    /// - 1-9: Low priority rules
    /// - 0: Fallback/default rules
    var priority: Int { get }
    
    /// Evaluate the rule against a post
    /// - Parameter post: The post to evaluate
    /// - Returns: ModerationResult with decision and metadata
    func evaluate(post: Post) async throws -> ModerationResult
}
