//
//  ManualModerationRule.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import Foundation

/// Default moderation rule that allows posts through
/// This serves as the fallback rule when no other rules apply
/// Can be configured to require manual review by changing defaultStatus
class ManualModerationRule: ModerationRule {
    let name = "Manual Moderation"
    let priority = 0 // Lowest priority - runs last as fallback
    
    /// Default status to apply (can be changed to .pending to require manual review)
    private let defaultStatus: ModerationStatus
    
    /// Whether this rule should be the final decision
    private let isFinalDecision: Bool
    
    init(defaultStatus: ModerationStatus = .approved, isFinalDecision: Bool = true) {
        self.defaultStatus = defaultStatus
        self.isFinalDecision = isFinalDecision
    }
    
    func evaluate(post: Post) async throws -> ModerationResult {
        Logger.debug("ManualModerationRule: Applying default status \(defaultStatus)", service: "ModerationService")
        
        return ModerationResult(
            status: defaultStatus,
            reason: defaultStatus == .pending ? "Awaiting manual review" : nil,
            metadata: ["rule": "manual_moderation"],
            shouldContinueEvaluation: !isFinalDecision
        )
    }
}
