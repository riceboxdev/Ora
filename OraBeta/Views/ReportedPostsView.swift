//
//  ReportedPostsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/24/25.
//

import SwiftUI
import OraBetaAdmin
import FirebaseAuth

struct ReportedPostsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var reports: [UserReport] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if reports.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Reports")
                        .font(.headline)
                    Text("You haven't reported any posts yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(reports, id: \.id) { report in
                    ReportRow(report: report)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("My Reports")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReports()
        }
        .task {
            await loadReports()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func loadReports() async {
        guard let currentUser = authViewModel.currentUser else {
            errorMessage = "You must be logged in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let firebaseToken = try await currentUser.getIDToken()
            let config = AdminConfig(baseURL: Config.adminAPIBaseURL)
            let client = AdminClient(config: config)
            
            let response = try await client.getMyReports(firebaseToken: firebaseToken)
            reports = response.reports
        } catch {
            errorMessage = "Failed to load reports: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct ReportRow: View {
    let report: UserReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Post Preview
            if let post = report.post {
                HStack(spacing: 12) {
                    if let imageUrl = post.thumbnailUrl ?? post.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let caption = post.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.caption)
                                .lineLimit(2)
                        } else {
                            Text("No caption")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Divider()
            
            // Report Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reason:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(report.reason.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if let description = report.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Status
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    StatusBadge(status: report.status)
                }
                .padding(.top, 4)
                
                // Moderation Action (if taken)
                if let post = report.post,
                   let moderationStatus = post.moderationStatus,
                   moderationStatus != "approved" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action Taken:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(moderationStatus.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor(moderationStatus))
                        
                        if let reason = post.moderationReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Report Date
                if let createdAt = report.createdAt {
                    Text("Reported: \(formatDate(createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved":
            return .green
        case "rejected":
            return .red
        case "flagged", "pending":
            return .orange
        default:
            return .secondary
        }
    }
    
    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "resolved":
            return .green
        case "dismissed":
            return .gray
        default:
            return .secondary
        }
    }
}

