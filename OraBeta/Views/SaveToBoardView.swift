//
//  SaveToBoardView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct SaveToBoardView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    private let boardService: BoardService
    private let engagementService: EngagementService
    @State private var boards: [Board] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(post: Post) {
        self.post = post
        let bs = BoardService()
        self.boardService = bs
        self.engagementService = EngagementService(boardService: bs)
    }
    
    var body: some View {
        NavigationView {
            List {
                if boards.isEmpty {
                    Text("No boards yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(boards) { board in
                        Button(action: {
                            Task {
                                await saveToBoard(board)
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(board.title)
                                        .font(.headline)
                                    if let description = board.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("\(board.postCount) posts")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Save to Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadBoards()
            }
        }
    }
    
    private func loadBoards() async {
        guard let userId = authViewModel.currentUser?.uid else {
            return
        }
        
        do {
            boards = try await boardService.getUserBoards(userId: userId)
        } catch {
            print("Error loading boards: \(error)")
        }
    }
    
    private func saveToBoard(_ board: Board) async {
        guard let boardId = board.id else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await engagementService.savePostToBoard(postId: post.activityId, boardId: boardId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    SaveToBoardView(
        post: Post(
            activityId: "1",
            userId: "user1",
            imageUrl: "https://example.com/image.jpg"
        )
    )
    .environmentObject(AuthViewModel())
}

