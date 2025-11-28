//
//  ContentFilterService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ContentFilterService {
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
    
    /// Add blocked tag
    func addBlockedTag(_ tag: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedTags = settings.blockedTags ?? []
        if !blockedTags.contains(tag) {
            blockedTags.append(tag)
            settings.blockedTags = blockedTags
            settings.updatedAt = Date()
            try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
            print("✅ ContentFilterService: Added blocked tag: \(tag)")
        }
    }
    
    /// Remove blocked tag
    func removeBlockedTag(_ tag: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedTags = settings.blockedTags ?? []
        blockedTags.removeAll { $0 == tag }
        settings.blockedTags = blockedTags.isEmpty ? nil : blockedTags
        settings.updatedAt = Date()
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ ContentFilterService: Removed blocked tag: \(tag)")
    }
    
    /// Add blocked category
    func addBlockedCategory(_ category: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedCategories = settings.blockedCategories ?? []
        if !blockedCategories.contains(category) {
            blockedCategories.append(category)
            settings.blockedCategories = blockedCategories
            settings.updatedAt = Date()
            try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
            print("✅ ContentFilterService: Added blocked category: \(category)")
        }
    }
    
    /// Remove blocked category
    func removeBlockedCategory(_ category: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedCategories = settings.blockedCategories ?? []
        blockedCategories.removeAll { $0 == category }
        settings.blockedCategories = blockedCategories.isEmpty ? nil : blockedCategories
        settings.updatedAt = Date()
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ ContentFilterService: Removed blocked category: \(category)")
    }
    
    /// Add blocked label
    func addBlockedLabel(_ label: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedLabels = settings.blockedLabels ?? []
        if !blockedLabels.contains(label) {
            blockedLabels.append(label)
            settings.blockedLabels = blockedLabels
            settings.updatedAt = Date()
            try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
            print("✅ ContentFilterService: Added blocked label: \(label)")
        }
    }
    
    /// Remove blocked label
    func removeBlockedLabel(_ label: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var blockedLabels = settings.blockedLabels ?? []
        blockedLabels.removeAll { $0 == label }
        settings.blockedLabels = blockedLabels.isEmpty ? nil : blockedLabels
        settings.updatedAt = Date()
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ ContentFilterService: Removed blocked label: \(label)")
    }
    
    /// Update mature content filter
    func updateMatureContentFilter(_ enabled: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.matureContentFilter = enabled
        settings.updatedAt = Date()
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ ContentFilterService: Updated mature content filter: \(enabled)")
    }
    
    /// Get account settings
    func getAccountSettings() async throws -> AccountSettings {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ContentFilterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        return try await getOrCreateSettings(userId: userId)
    }
}

