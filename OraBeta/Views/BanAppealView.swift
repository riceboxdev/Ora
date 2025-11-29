//
//  BanAppealView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct BanAppealView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var banService = BanService()
    
    @State private var appealReason: String = ""
    @State private var isSubmittingAppeal = false
    @State private var showAppealSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            gridLinesBackground()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Title
                    Text("Submit an Appeal")
                        .font(.creatoDisplayTitle())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Description
                    Text("If you believe this ban was made in error, you can submit an appeal for review.")
                        .font(.creatoDisplayBody())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Appeal Form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appeal Reason")
                            .font(.creatoDisplayHeadline())
                        
                        ZStack(alignment: .topLeading) {
                            if appealReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Please provide a reason for your appeal")
                                    .font(.creatoDisplayBody(.regular))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $appealReason)
                                .font(.creatoDisplayBody(.regular))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                        
                        Button(action: {
                            Task {
                                await submitAppeal()
                            }
                        }) {
                            HStack {
                                if isSubmittingAppeal {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isSubmittingAppeal ? "Submitting..." : "Submit Appeal")
                                    .font(.creatoDisplayHeadline())
                                    .foregroundColor(.whiteui)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(10)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isSubmittingAppeal || appealReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Appeal Submitted", isPresented: $showAppealSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your appeal has been submitted and is under review. You will be notified of the decision.")
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
    }
    
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
    
    private func submitAppeal() async {
        guard !appealReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ BanAppealView: Cannot submit appeal - reason is empty")
            return
        }
        
        print("🔄 BanAppealView: Starting appeal submission...")
        print("   Appeal reason length: \(appealReason.count) characters")
        
        isSubmittingAppeal = true
        errorMessage = nil
        
        do {
            print("📤 BanAppealView: Calling banService.submitAppeal...")
            let appealId = try await banService.submitAppeal(reason: appealReason)
            print("✅ BanAppealView: Appeal submitted successfully! Appeal ID: \(appealId)")
            
            showAppealSuccess = true
            appealReason = ""
        } catch {
            print("❌ BanAppealView: Error submitting appeal")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error userInfo: \(nsError.userInfo)")
                
                // Try to extract more details
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("   Underlying error: \(underlyingError.localizedDescription)")
                    print("   Underlying domain: \(underlyingError.domain)")
                    print("   Underlying code: \(underlyingError.code)")
                }
            }
            
            Logger.error("Failed to submit appeal: \(error.localizedDescription)", service: "BanAppealView")
            errorMessage = "Failed to submit appeal: \(error.localizedDescription)"
        }
        
        isSubmittingAppeal = false
        print("🏁 BanAppealView: Appeal submission finished")
    }
}

#Preview {
    NavigationStack {
        BanAppealView()
    }
}






