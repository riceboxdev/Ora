import Foundation
import FirebaseFirestore

class InterestService {
    private let db = Firestore.firestore()
    private let interestCollection = Firestore.firestore().collection("interests")
    
    // MARK: - CRUD Operations
    
    /// Fetch all interests with optional filtering and pagination
    func fetchInterests(
        parentId: String? = nil,
        searchTerm: String? = nil,
        isActive: Bool? = nil,
        limit: Int = 20,
        lastDocument: DocumentSnapshot? = nil
    ) async throws -> (interests: [Interest], lastDocument: DocumentSnapshot?) {
        var query = interestCollection.limit(to: limit)
        
        // Apply filters
        if let parentId = parentId {
            query = query.whereField("parentId", isEqualTo: parentId)
        } else {
            query = query.whereField("level", isEqualTo: 0) // Root level by default
        }
        
        if let isActive = isActive {
            query = query.whereField("isActive", isEqualTo: isActive)
        }
        
        if let searchTerm = searchTerm, !searchTerm.isEmpty {
            // For more advanced search, consider using Algolia or similar
            query = query.whereField("keywords", arrayContains: searchTerm.lowercased())
        }
        
        // Apply pagination
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        let interests = try snapshot.documents.compactMap { document in
            try document.data(as: Interest.self)
        }
        
        return (interests, snapshot.documents.last)
    }
    
    /// Get a single interest by ID
    func getInterest(id: String) async throws -> Interest {
        let document = try await interestCollection.document(id).getDocument()
        guard let interest = try? document.data(as: Interest.self) else {
            throw NSError(domain: "com.ora.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "Interest not found"])
        }
        return interest
    }
    
    /// Create a new interest
    func createInterest(_ interest: Interest) async throws -> Interest {
        // Validate name is unique
        let existing = try await interestCollection.whereField("name", isEqualTo: interest.name).getDocuments()
        guard existing.documents.isEmpty else {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "An interest with this name already exists"])
        }
        
        // Add timestamps
        let interestWithTimestamps = Interest(
            id: interest.id,
            name: interest.name,
            displayName: interest.displayName,
            parentId: interest.parentId,
            level: interest.level,
            path: interest.path,
            description: interest.description,
            coverImageUrl: interest.coverImageUrl,
            isActive: interest.isActive,
            createdAt: Date(),
            updatedAt: Date(),
            postCount: 0,
            followerCount: 0,
            weeklyGrowth: 0,
            monthlyGrowth: 0,
            relatedInterestIds: interest.relatedInterestIds,
            keywords: interest.keywords,
            synonyms: interest.synonyms
        )
        
        try interestCollection.document(interest.id).setData(from: interestWithTimestamps)
        return interestWithTimestamps
    }
    
    /// Update an existing interest
    func updateInterest(id: String, updates: [String: Any]) async throws -> Interest {
        var updateData = updates
        updateData["updatedAt"] = FieldValue.serverTimestamp()
        
        // Don't allow updating certain fields
        updateData.removeValue(forKey: "id")
        updateData.removeValue(forKey: "createdAt")
        updateData.removeValue(forKey: "path") // Path should be updated via move operation
        
        // If name is being updated, check for duplicates
        if let newName = updates["name"] as? String {
            let existing = try await interestCollection
                .whereField("name", isEqualTo: newName)
                .whereField(FieldPath.documentID(), isNotEqualTo: id)
                .getDocuments()
            
            guard existing.documents.isEmpty else {
                throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "An interest with this name already exists"])
            }
        }
        
        try await interestCollection.document(id).updateData(updateData)
        return try await getInterest(id: id)
    }
    
    /// Delete an interest and its children
    func deleteInterest(id: String) async throws {
        // In a real implementation, you might want to:
        // 1. Check if interest has children and either prevent deletion or delete them recursively
        // 2. Handle references in other collections (posts, user interests, etc.)
        
        // For now, we'll just delete the interest
        try await interestCollection.document(id).delete()
    }
    
    // MARK: - Hierarchy Operations
    
    /// Move an interest to a new parent
    func moveInterest(id: String, newParentId: String?) async throws -> Interest {
        let interest = try await getInterest(id: id)
        
        // Prevent cycles (can't make an interest a child of itself or its descendants)
        if let newParentId = newParentId {
            if newParentId == id {
                throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot make an interest a child of itself"])
            }
            
            // Check if new parent is a descendant of this interest
            let isDescendant = try await isDescendant(interestId: newParentId, of: id)
            if isDescendant {
                throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot create a cycle in the interest hierarchy"])
            }
        }
        
        // Get the new parent's path
        let newParentPath: [String]
        let newLevel: Int
        
        if let newParentId = newParentId {
            let parent = try await getInterest(id: newParentId)
            newParentPath = parent.path + [parent.id]
            newLevel = parent.level + 1
        } else {
            newParentPath = []
            newLevel = 0
        }
        
        // Update the interest
        try await interestCollection.document(id).updateData([
            "parentId": newParentId as Any,
            "level": newLevel,
            "path": newParentPath,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update all descendants' paths and levels
        try await updateDescendantPaths(interestId: id, newParentPath: newParentPath, newLevel: newLevel)
        
        return try await getInterest(id: id)
    }
    
    // MARK: - Import/Export
    
    /// Export interests as CSV data
    func exportInterests() async throws -> Data {
        let query = interestCollection.order(by: "path")
        let snapshot = try await query.getDocuments()
        let interests = try snapshot.documents.compactMap { try $0.data(as: Interest.self) }
        
        // Convert to CSV
        var csv = "id,name,displayName,parentId,level,path,description,isActive\n"
        
        for interest in interests {
            let row = [
                interest.id,
                interest.name,
                interest.displayName,
                interest.parentId ?? "",
                String(interest.level),
                interest.path.joined(separator: ">"),
                interest.description?.replacingOccurrences(of: "\"", with: "\"\"") ?? "",
                interest.isActive ? "true" : "false"
            ].map { "\\($0.replacingOccurrences(of: "\"", with: "\"\""))" }
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        guard let data = csv.data(using: .utf8) else {
            throw NSError(domain: "com.ora.error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CSV data"])
        }
        
        return data
    }
    
    /// Import interests from CSV data
    func importInterests(from data: Data, dryRun: Bool = false) async throws -> ImportResult {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV data"])
        }
        
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { // At least header + 1 row
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "CSV file is empty"])
        }
        
        let header = lines[0].components(separatedBy: ",")
        var result = ImportResult(created: 0, updated: 0, errors: [])
        
        // Process each row
        for (index, line) in lines.dropFirst().enumerated() {
            let columns = parseCSVLine(line)
            guard columns.count >= 8 else {
                result.errors.append("Row \(index + 2): Invalid number of columns")
                continue
            }
            
            do {
                let id = columns[0]
                let name = columns[1]
                let displayName = columns[2]
                let parentId = columns[3].isEmpty ? nil : columns[3]
                let level = Int(columns[4]) ?? 0
                let path = columns[5].split(separator: ">").map(String.init)
                let description = columns[6].isEmpty ? nil : columns[6]
                let isActive = columns[7].lowercased() == "true"
                
                let interest = Interest(
                    id: id,
                    name: name,
                    displayName: displayName,
                    parentId: parentId,
                    level: level,
                    path: path,
                    description: description,
                    coverImageUrl: nil,
                    isActive: isActive,
                    createdAt: Date(),
                    updatedAt: Date(),
                    postCount: 0,
                    followerCount: 0,
                    weeklyGrowth: 0,
                    monthlyGrowth: 0,
                    relatedInterestIds: [],
                    keywords: [],
                    synonyms: []
                )
                
                if dryRun {
                    // Just validate without saving
                    try validateInterest(interest)
                    result.created += 1
                } else {
                    // Check if interest exists
                    let doc = try await interestCollection.document(id).getDocument()
                    
                    if doc.exists {
                        try await updateInterest(id: id, updates: try interest.toFirestoreData())
                        result.updated += 1
                    } else {
                        try await createInterest(interest)
                        result.created += 1
                    }
                }
            } catch {
                result.errors.append("Row \(index + 2): \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func isDescendant(interestId: String, of potentialAncestorId: String) async throws -> Bool {
        var currentId = interestId
        
        // Limit the depth to prevent infinite loops
        var depth = 0
        let maxDepth = 20
        
        while depth < maxDepth {
            let doc = try await interestCollection.document(currentId).getDocument()
            guard let data = doc.data(),
                  let parentId = data["parentId"] as? String else {
                return false // Reached root
            }
            
            if parentId == potentialAncestorId {
                return true
            }
            
            currentId = parentId
            depth += 1
        }
        
        return false
    }
    
    private func updateDescendantPaths(interestId: String, newParentPath: [String], newLevel: Int) async throws {
        // Get all direct children
        let children = try await interestCollection
            .whereField("parentId", isEqualTo: interestId)
            .getDocuments()
        
        // Update each child's path and level
        for document in children.documents {
            let childId = document.documentID
            let childNewPath = newParentPath + [interestId]
            
            try await interestCollection.document(childId).updateData([
                "path": childNewPath,
                "level": newLevel + 1,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Recursively update all descendants
            try await updateDescendantPaths(interestId: childId, newParentPath: childNewPath, newLevel: newLevel + 1)
        }
    }
    
    private func validateInterest(_ interest: Interest) throws {
        // Name validation
        guard !interest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])
        }
        
        guard interest.name == interest.name.lowercased() else {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Name must be lowercase"])
        }
        
        // Display name validation
        guard !interest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Display name cannot be empty"])
        }
        
        // Level validation
        if interest.parentId == nil && interest.level != 0 {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Root interests must have level 0"])
        }
        
        if interest.parentId != nil && interest.level <= 0 {
            throw NSError(domain: "com.ora.error", code: 400, userInfo: [NSLocalizedDescriptionKey: "Child interests must have level > 0"])
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        result.append(currentField)
        
        return result
    }
}

// MARK: - Models

struct ImportResult {
    var created: Int
    var updated: Int
    var errors: [String]
    
    init(created: Int = 0, updated: Int = 0, errors: [String] = []) {
        self.created = created
        self.updated = updated
        self.errors = errors
    }
}
