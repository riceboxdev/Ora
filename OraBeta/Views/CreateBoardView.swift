//
//  CreateBoardView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct CreateBoardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    var boardService: BoardService
    
    @State private var title = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Board Information")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Private", isOn: $isPrivate)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createBoard()
                        }
                    }
                    .disabled(isLoading || title.isEmpty)
                }
            }
        }
    }
    
    private func createBoard() async {
        guard let userId = authViewModel.currentUser?.uid else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let board = Board(
            title: title,
            description: description.isEmpty ? nil : description,
            isPrivate: isPrivate,
            userId: userId
        )
        
        do {
            _ = try await boardService.createBoard(board)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    CreateBoardView(boardService: BoardService())
        .environmentObject(AuthViewModel())
}

