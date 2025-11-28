//
//  DiscoveryPreferencesService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class DiscoveryPreferencesService {
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
    
    /// Update algorithm preference
    func updateAlgorithmPreference(_ preference: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard ["personalized", "trending", "balanced"].contains(preference) else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid algorithm preference"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.algorithmPreference = preference
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ DiscoveryPreferencesService: Updated algorithm preference to \(preference)")
    }
    
    /// Add content type preference
    func addContentTypePreference(_ contentType: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var contentTypePreferences = settings.contentTypePreference ?? []
        if !contentTypePreferences.contains(contentType) {
            contentTypePreferences.append(contentType)
            settings.contentTypePreference = contentTypePreferences
            settings.updatedAt = Date()
            try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
            print("✅ DiscoveryPreferencesService: Added content type preference: \(contentType)")
        }
    }
    
    /// Remove content type preference
    func removeContentTypePreference(_ contentType: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        var contentTypePreferences = settings.contentTypePreference ?? []
        contentTypePreferences.removeAll { $0 == contentType }
        settings.contentTypePreference = contentTypePreferences.isEmpty ? nil : contentTypePreferences
        settings.updatedAt = Date()
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ DiscoveryPreferencesService: Removed content type preference: \(contentType)")
    }
    
    /// Update personalized and trending weights
    func updateWeights(personalizedWeight: Double, trendingWeight: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard personalizedWeight >= 0 && personalizedWeight <= 1 && trendingWeight >= 0 && trendingWeight <= 1 else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Weights must be between 0 and 1"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.personalizedWeight = personalizedWeight
        settings.trendingWeight = trendingWeight
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ DiscoveryPreferencesService: Updated weights (personalized: \(personalizedWeight), trending: \(trendingWeight))")
    }
    
    /// Update preferred language
    func updatePreferredLanguage(_ language: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var settings = try await getOrCreateSettings(userId: userId)
        settings.preferredLanguage = language
        settings.updatedAt = Date()
        
        try await db.collection(accountSettingsCollection).document(userId).setData(from: settings, merge: true)
        print("✅ DiscoveryPreferencesService: Updated preferred language to \(language ?? "nil")")
    }
    
    /// Get account settings
    func getAccountSettings() async throws -> AccountSettings {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DiscoveryPreferencesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        return try await getOrCreateSettings(userId: userId)
    }
}

