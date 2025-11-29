//
//  ReportPostSheet.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/24/25.
//

import SwiftUI
import OraBetaAdmin
import FirebaseAuth

struct ReportPostSheet: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedReason: String = "inappropriate"
    @State private var description: String = ""
    @State private var isReporting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    private let reportReasons = [
        ("spam", "Spam"),
        ("inappropriate", "Inappropriate Content"),
        ("harassment", "Harassment"),
        ("violence", "Violence"),
        ("other", "Other")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Why are you reporting this post?")) {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reportReasons, id: \.0) { reason in
                            Text(reason.1).tag(reason.0)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Additional Details (Optional)")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task {
                            await reportPost()
                        }
                    }
                    .disabled(isReporting)
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for reporting this post. It will be reviewed by our moderation team.")
            }
        }
    }
    
    private func reportPost() async {
        guard let currentUser = authViewModel.currentUser else {
            errorMessage = "You must be logged in to report a post"
            return
        }
        
        isReporting = true
        errorMessage = nil
        
        do {
            let firebaseToken = try await currentUser.getIDToken()
            let config = AdminConfig()
            let client = AdminClient(config: config)
            
            try await client.reportPost(
                postId: post.id,
                reason: selectedReason,
                description: description.isEmpty ? nil : description,
                firebaseToken: firebaseToken
            )
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to report post: \(error.localizedDescription)"
        }
        
        isReporting = false
    }
}













