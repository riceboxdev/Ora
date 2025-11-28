//
//  BoardDetailView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import MasonryStack

struct BoardDetailView: View {
    let board: Board
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    private let boardService: BoardService
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    init(board: Board) {
        self.board = board
        self.boardService = BoardService()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Board Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(board.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let description = board.description {
                        Text(description)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(board.postCount) posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Posts Grid
                if isLoading && posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if posts.isEmpty {
                    Text("No posts in this board")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    PostGrid(posts: posts)
                        .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete Board", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteBoard()
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(board.title)\"? This action cannot be undone.")
        }
        .task {
            await loadPosts(boardService: boardService)
        }
    }
    
    private func loadPosts(boardService: BoardService) async {
        guard let boardId = board.id else {
            return
        }
        
        isLoading = true
        do {
            posts = try await boardService.getBoardPosts(boardId: boardId)
        } catch {
            print("Error loading board posts: \(error)")
        }
        isLoading = false
    }
    
    private func deleteBoard() async {
        guard let boardId = board.id else {
            return
        }
        
        isDeleting = true
        errorMessage = nil
        
        do {
            try await boardService.deleteBoard(boardId: boardId)
            print("✅ BoardDetailView: Board deleted successfully")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ BoardDetailView: Error deleting board: \(error)")
        }
        
        isDeleting = false
    }
}

#Preview {
    NavigationView {
        BoardDetailView(
            board: Board(
                title: "My Board",
                description: "A test board",
                userId: "user1"
            )
        )
    }
}

