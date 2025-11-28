//
//  AccountVisibilityService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class AccountVisibilityService {
    private let db = Firestore.firestore()
    private let accountSettingsCollection = "account_settings"
    
    /// Get account settings (creates default if doesn't exist)
    private func getOrCreateSettings(userId: String) async throws -> AccountSettings {
        let docRef = db.collection(accountSettingsCollection).document(userId)
        let doc = try await docRef.getDocument()
        
        if doc.exists {
            var settings = try doc.data(as: AccountSettings.self)
            settings.id = doc.documentID
            return settings
        } else {
            // Create default settings
            let defaultSettings = AccountSettings(id: userId)
            try await docRef.setData(from: defaultSettings)
            return defaultSettings
        }
    }
    
    /// Update account visibility
    func updateAccountVisibility(_ visibility: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard visibility == "public" || visibility == "private" else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid visibility value"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.accountVisibility = visibility
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ AccountVisibilityService: Updated account visibility to \(visibility)")
    }
    
    /// Update profile visibility
    func updateProfileVisibility(_ visibility: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard visibility == "public" || visibility == "private" else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid visibility value"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.profileVisibility = visibility
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ AccountVisibilityService: Updated profile visibility to \(visibility)")
    }
    
    /// Update content visibility
    func updateContentVisibility(_ visibility: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard visibility == "public" || visibility == "private" else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid visibility value"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.contentVisibility = visibility
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ AccountVisibilityService: Updated content visibility to \(visibility)")
    }
    
    /// Get account settings
    func getAccountSettings() async throws -> AccountSettings {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AccountVisibilityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        return try await getOrCreateSettings(userId: userId)
    }
}

