//
//  InterestAdminService.swift
//  OraBeta
//
//  Admin service for managing the interest taxonomy
//  Provides endpoints for CRUD operations on interests
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class InterestAdminService {
    private let interestService: InterestTaxonomyService
    private let seedDataService: InterestSeedDataService
    
    init(
        interestService: InterestTaxonomyService = .shared,
        seedDataService: InterestSeedDataService? = nil
    ) {
        self.interestService = interestService
        self.seedDataService = seedDataService ?? InterestSeedDataService(interestService: interestService)
    }
    
    // MARK: - Admin Operations
    
    /// Initialize taxonomy with seed data (admin only)
    func initializeTaxonomyWithSeedData() async throws {
        try await seedDataService.seedAllInterests()
        interestService.clearCache()
    }
    
    /// Create a new root interest (admin only)
    func createRootInterest(
        name: String,
        displayName: String,
        description: String? = nil,
        keywords: [String] = [],
        synonyms: [String] = []
    ) async throws -> Interest {
        return try await interestService.createInterest(
            name: name,
            displayName: displayName,
            parentId: nil,
            description: description,
            keywords: keywords,
            synonyms: synonyms
        )
    }
    
    /// Create a child interest under a parent (admin only)
    func createChildInterest(
        name: String,
        displayName: String,
        parentId: String,
        description: String? = nil,
        keywords: [String] = [],
        synonyms: [String] = []
    ) async throws -> Interest {
        _ = try await interestService.getInterest(id: parentId)
        
        return try await interestService.createInterest(
            name: name,
            displayName: displayName,
            parentId: parentId,
            description: description,
            keywords: keywords,
            synonyms: synonyms
        )
    }
    
    /// Update interest metadata (admin only)
    func updateInterest(
        id: String,
        displayName: String? = nil,
        description: String? = nil,
        keywords: [String]? = nil,
        synonyms: [String]? = nil,
        relatedInterestIds: [String]? = nil,
        isActive: Bool? = nil
    ) async throws -> Interest {
        return try await interestService.updateInterest(
            id: id,
            displayName: displayName,
            description: description,
            keywords: keywords,
            synonyms: synonyms,
            relatedInterestIds: relatedInterestIds,
            isActive: isActive
        )
    }
    
    /// Deactivate an interest (admin only)
    func deactivateInterest(id: String) async throws {
        try await interestService.deactivateInterest(id: id)
    }
    
    /// Get all interests for admin management
    func getAllInterestsForAdmin() async throws -> [Interest] {
        return try await interestService.getAllInterests()
    }
    
    /// Get interest tree for admin UI
    func getInterestTreeForAdmin(maxDepth: Int? = nil) async throws -> [Interest] {
        return try await interestService.getInterestTree(maxDepth: maxDepth)
    }
    
    /// Rebuild relationships between interests
    func updateRelatedInterests(
        interestId: String,
        relatedInterestIds: [String]
    ) async throws -> Interest {
        return try await interestService.updateInterest(
            id: interestId,
            relatedInterestIds: relatedInterestIds
        )
    }
    
    /// Bulk import interests from array
    func bulkImportInterests(_ seeds: [InterestSeed]) async throws {
        for seed in seeds {
            try await interestService.createInterest(
                name: seed.name,
                displayName: seed.displayName,
                parentId: seed.parentId,
                description: seed.description,
                keywords: seed.keywords,
                synonyms: seed.synonyms
            )
        }
        interestService.clearCache()
    }
}
