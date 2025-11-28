//
//  CollectionsViewModel.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class CollectionsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var boards: [Board] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var boardService: BoardService
    let profileService: ProfileServiceProtocol
    private var currentUserId: String?
    private let container: DIContainer
    
    // MARK: - Initialization
    init(container: DIContainer? = nil) {
        let diContainer = container ?? DIContainer.shared
        self.container = diContainer
        self.profileService = diContainer.profileService
        self.boardService = diContainer.boardService
    }
    
    // MARK: - Public Methods
    
    /// Load initial data (boards)
    func loadInitialData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ CollectionsViewModel: Cannot load data - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        await loadBoards()
    }
    
    /// Load boards for the current user
    func loadBoards() async {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("⚠️ CollectionsViewModel: Cannot load boards - no user ID")
            errorMessage = "Not authenticated"
            return
        }
        
        currentUserId = userId
        
        print("🔄 CollectionsViewModel: Loading boards for user \(userId)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedBoards = try await boardService.getUserBoards(userId: userId)
            boards = loadedBoards
            
            print("✅ CollectionsViewModel: Loaded \(loadedBoards.count) boards")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ CollectionsViewModel: Error loading boards: \(error)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error description: \(nsError.localizedDescription)")
            }
        }
        
        isLoading = false
    }
}

