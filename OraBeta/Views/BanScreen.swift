//
//  BanScreen.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct BanScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var banService = BanService()
    
    @State private var banReason: String?
    @State private var bannedAt: Date?
    @State private var currentAppeal: BanAppeal?
    @State private var errorMessage: String?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                gridLinesBackground()
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    
                        VStack(spacing: 30) {
                            Spacer()
                                .frame(height: 40)
                            
                            // Ban Icon
                            Image("face.sad")
                                .font(.system(size: 80))
                                .foregroundColor(.red)
                            
                            // Title
                            Text("Account Banned")
                                .font(.creatoDisplayTitle())
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Ban Message
                            Text("Your account has been banned from using this service.")
                                .font(.creatoDisplayBody())
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            // Ban Details
                            if banReason != nil || bannedAt != nil {
                                VStack(alignment: .leading, spacing: 16) {
                                    if let reason = banReason, !reason.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Reason")
                                                .font(.creatoDisplayCaption(.medium))
                                                .foregroundColor(.secondary)
                                            Text(reason)
                                                .font(.creatoDisplayBody(.regular))
                                        }
                                    }
                                    
                                    if let bannedDate = bannedAt {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Banned On")
                                                .font(.creatoDisplayCaption(.medium))
                                                .foregroundColor(.secondary)
                                            Text(formatDate(bannedDate))
                                                .font(.creatoDisplayBody(.regular))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Appeal Section
                            if let appeal = currentAppeal {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Appeal Status")
                                            .font(.creatoDisplayCaption(.medium))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        statusBadge(status: appeal.status)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Your Appeal")
                                            .font(.creatoDisplayCaption(.medium))
                                            .foregroundColor(.secondary)
                                        Text(appeal.reason)
                                            .font(.creatoDisplayBody(.regular))
                                    }
                                    
                                    if let reviewedAt = appeal.reviewedAt {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Reviewed On")
                                                .font(.creatoDisplayCaption(.medium))
                                                .foregroundColor(.secondary)
                                            Text(formatDate(reviewedAt))
                                                .font(.creatoDisplayBody(.regular))
                                        }
                                    }
                                    
                                    if let reviewNotes = appeal.reviewNotes, !reviewNotes.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Review Notes")
                                                .font(.creatoDisplayCaption(.medium))
                                                .foregroundColor(.secondary)
                                            Text(reviewNotes)
                                                .font(.creatoDisplayBody(.regular))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                VStack(spacing: 12) {
                                    Text("You can submit an appeal if you think this was a mistake.")
                                        .font(.creatoDisplayBody())
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                    
                                    NavigationLink(destination: BanAppealView()) {
                                        Text("Submit an Appeal")
                                            .font(.creatoDisplayBody(.medium))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            Spacer()
                            
                            // Sign Out Button
                            Button(action: {
                                authViewModel.signOut()
                            }) {
                                Text("Sign Out")
                                    .font(.creatoDisplayHeadline())
                                    .foregroundColor(.blackui)
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.red)
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .task {
            await loadBanDetails()
        }
        .onChange(of: authViewModel.isBanned) { oldValue, newValue in
            // Immediately reload ban details when ban status changes
            if newValue {
                Task {
                    await loadBanDetails()
                }
            }
        }
        .onAppear {
            // Reload appeal when returning from appeal form
            Task {
                await loadAppeal()
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(0.3), location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
    
    private func statusBadge(status: BanAppealStatus) -> some View {
        let (text, color) = statusInfo(status: status)
        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
    
    private func statusInfo(status: BanAppealStatus) -> (String, Color) {
        switch status {
        case .pending:
            return ("Pending Review", Color.orange)
        case .approved:
            return ("Approved", Color.green)
        case .rejected:
            return ("Rejected", Color.red)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadBanDetails() async {
        isLoading = true
        do {
            let details = try await banService.getBanDetails()
            banReason = details.reason
            bannedAt = details.bannedAt
            await loadAppeal()
        } catch {
            errorMessage = "Failed to load ban details: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func loadAppeal() async {
        do {
            currentAppeal = try await banService.getCurrentAppeal()
        } catch {
            Logger.error("Failed to load appeal: \(error.localizedDescription)", service: "BanScreen")
        }
    }
    
}

#Preview("Banned User") {
    BanScreen()
        .previewAuthenticated(
            email: "banned@example.com",
            password: "password123",
            username: "banneduser"
        )
}
