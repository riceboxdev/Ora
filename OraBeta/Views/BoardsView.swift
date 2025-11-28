//
//  BoardsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct BoardsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: CollectionsViewModel
    @State private var showCreateBoard = false
    @State private var boardToDelete: Board?
    @State private var showDeleteConfirmation = false
    
    init() {
        // Create ViewModel with DIContainer services
        _viewModel = StateObject(wrappedValue: CollectionsViewModel())
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if viewModel.isLoading && viewModel.boards.isEmpty {
                    ProgressView()
                        .padding()
                } else if viewModel.boards.isEmpty {
                    VStack {
                        Text("No boards yet")
                            .foregroundColor(.secondary)
                        Button("Create Board") {
                            showCreateBoard = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.boards) { board in
                            NavigationLink(destination: BoardDetailView(board: board)
                                .environmentObject(authViewModel)
                                .onDisappear {
                                    // Reload boards when returning from detail view in case board was deleted
                                    Task {
                                        await viewModel.loadBoards()
                                    }
                                }) {
                                BoardCard(board: board)
                            }
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    boardToDelete = board
                                    showDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Boards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateBoard = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateBoard) {
                CreateBoardView(boardService: BoardService())
            }
            .task {
                // Update ViewModel with shared StreamService from AuthViewModel
                await viewModel.loadInitialData()
            }
            .alert("Delete Board", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    boardToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let board = boardToDelete {
                        Task {
                            await deleteBoard(board)
                        }
                    }
                }
            } message: {
                if let board = boardToDelete {
                    Text("Are you sure you want to delete \"\(board.title)\"? This action cannot be undone.")
                }
            }
        }
    }
    
    private func deleteBoard(_ board: Board) async {
        guard let boardId = board.id else {
            return
        }
        
        let boardService = BoardService()
        
        do {
            try await boardService.deleteBoard(boardId: boardId)
            print("✅ BoardsView: Board deleted successfully")
            // Reload boards to update the list
            await viewModel.loadBoards()
        } catch {
            print("❌ BoardsView: Error deleting board: \(error)")
        }
        
        boardToDelete = nil
    }
}

struct BoardCard: View {
    let board: Board
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coverImageUrl = board.coverImageUrl {
                AsyncImage(url: URL(string: coverImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }
            
            Text(board.title)
                .font(.headline)
                .lineLimit(1)
            
            if let description = board.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text("\(board.postCount) posts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    BoardsView()
        .environmentObject(AuthViewModel())
}


