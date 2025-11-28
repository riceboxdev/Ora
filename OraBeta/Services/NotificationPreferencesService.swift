//
//  NotificationPreferencesService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class NotificationPreferencesService: ObservableObject {
    static let shared = NotificationPreferencesService()
    
    @Published var preferences: NotificationPreferences = .default
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private init() {}
    
    /// Load notification preferences for current user
    func loadPreferences() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NotificationPreferencesError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("notification_preferences")
            .document("settings")
        
        let document = try await docRef.getDocument()
        
        if document.exists, let prefs = NotificationPreferences.from(document: document) {
            preferences = prefs
        } else {
            // Create default preferences
            preferences = .default
            try await savePreferences()
        }
    }
    
    /// Start listening to preference changes
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        stopListening()
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("notification_preferences")
            .document("settings")
        
        listener = docRef.addSnapshotListener { [weak self] document, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let document = document, document.exists,
                      let prefs = NotificationPreferences.from(document: document) else {
                    return
                }
                
                self.preferences = prefs
            }
        }
    }
    
    /// Stop listening to preference changes
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Save notification preferences
    func savePreferences() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NotificationPreferencesError.notAuthenticated
        }
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("notification_preferences")
            .document("settings")
        
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(preferences),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NotificationPreferencesError.encodingError
        }
        
        try await docRef.setData(jsonObject, merge: true)
    }
    
    /// Update a specific preference
    func updatePreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences, T>, value: T) async throws {
        preferences[keyPath: keyPath] = value
        try await savePreferences()
    }
    
    /// Update engagement preference
    func updateEngagementPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.EngagementPreferences, T>, value: T) async throws {
        preferences.engagement[keyPath: keyPath] = value
        try await savePreferences()
    }
    
    /// Update system preference
    func updateSystemPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.SystemPreferences, T>, value: T) async throws {
        preferences.system[keyPath: keyPath] = value
        try await savePreferences()
    }
    
    /// Update promotional preference
    func updatePromotionalPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.PromotionalPreferences, T>, value: T) async throws {
        preferences.promotional[keyPath: keyPath] = value
        try await savePreferences()
    }
    
    /// Update quiet hours preference
    func updateQuietHoursPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.QuietHours, T>, value: T) async throws {
        preferences.quietHours[keyPath: keyPath] = value
        try await savePreferences()
    }
}

enum NotificationPreferencesError: LocalizedError {
    case notAuthenticated
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .encodingError:
            return "Failed to encode preferences"
        case .decodingError:
            return "Failed to decode preferences"
        }
    }
}

