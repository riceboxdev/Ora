//
//  ModerationBadgeView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import SwiftUI

/// Displays a badge indicating the moderation status of a post
struct ModerationBadgeView: View {
    let status: ModerationStatus
    let compact: Bool
    
    init(status: ModerationStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }
    
   var body: some View {
        if !compact || status != .approved {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption2)
                
                if !compact {
                    Text(status.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(compact ? 4 : 6)
        }
    }
    
    private var iconName: String {
        switch status {
        case .pending:
            return "clock.fill"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .flagged:
            return "flag.fill"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return .yellow.opacity(0.2)
        case .approved:
            return .green.opacity(0.2)
        case .rejected:
            return .red.opacity(0.2)
        case .flagged:
            return .orange.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .pending:
            return .yellow
        case .approved:
            return .green
        case .rejected:
            return .red
        case .flagged:
            return .orange
        }
    }
}

#Preview("All Statuses") {
    VStack(spacing: 12) {
        ForEach(ModerationStatus.allCases, id: \.self) { status in
            VStack(alignment: .leading, spacing: 8) {
                Text(status.displayName)
                    .font(.headline)
                
                HStack {
                    ModerationBadgeView(status: status)
                    ModerationBadgeView(status: status, compact: true)
                }
            }
        }
    }
    .padding()
}
