//
//  PushNotificationService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Register FCM token for current user
    func registerToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Store token in user's fcm_tokens collection
        let tokenRef = db
            .collection("users")
            .document(userId)
            .collection("fcm_tokens")
            .document(token)
        
        try await tokenRef.setData([
            "token": token,
            "enabled": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Remove FCM token
    func removeToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let tokenRef = db
            .collection("users")
            .document(userId)
            .collection("fcm_tokens")
            .document(token)
        
        try await tokenRef.delete()
    }
    
    /// Update token enabled status
    func updateTokenEnabled(_ token: String, enabled: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let tokenRef = db
            .collection("users")
            .document(userId)
            .collection("fcm_tokens")
            .document(token)
        
        try await tokenRef.updateData([
            "enabled": enabled,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
}










