//
//  BanService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Combine

@MainActor
class BanService: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let banAppealsCollection = "ban_appeals"
    private var banListener: ListenerRegistration?
    
    // Get Functions instance
    private var functions: Functions {
        return FunctionsConfig.functions(region: "us-central1")
    }
    
    /// Check if current user is banned
    func isBanned() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        let doc = try await db.collection(usersCollection).document(userId).getDocument()
        guard doc.exists, let data = doc.data() else {
            return false
        }
        
        return data["isBanned"] as? Bool ?? false
    }
    
    /// Get ban details for current user
    func getBanDetails() async throws -> (isBanned: Bool, reason: String?, bannedAt: Date?) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return (false, nil, nil)
        }
        
        let doc = try await db.collection(usersCollection).document(userId).getDocument()
        guard doc.exists, let data = doc.data() else {
            return (false, nil, nil)
        }
        
        let isBanned = data["isBanned"] as? Bool ?? false
        let reason = data["banReason"] as? String
        var bannedAt: Date? = nil
        
        if let timestamp = data["bannedAt"] as? Timestamp {
            bannedAt = timestamp.dateValue()
        }
        
        return (isBanned, reason, bannedAt)
    }
    
    /// Start listening to ban status changes for current user
    /// - Parameter onBanStatusChanged: Callback when ban status changes
    func startListeningToBanStatus(onBanStatusChanged: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        stopListening()
        
        let userRef = db.collection(usersCollection).document(userId)
        
        banListener = userRef.addSnapshotListener { [weak self] documentSnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.error("Error listening to ban status: \(error.localizedDescription)", service: "BanService")
                    return
                }
                
                guard let document = documentSnapshot, document.exists,
                      let data = document.data() else {
                    onBanStatusChanged(false)
                    return
                }
                
                let isBanned = data["isBanned"] as? Bool ?? false
                Logger.info("Ban status changed: \(isBanned)", service: "BanService")
                onBanStatusChanged(isBanned)
            }
        }
    }
    
    /// Stop listening to ban status changes
    func stopListening() {
        banListener?.remove()
        banListener = nil
    }
    
    /// Submit a ban appeal
    func submitAppeal(reason: String) async throws -> String {
        print("🔄 BanService: submitAppeal called")
        print("   Reason length: \(reason.count) characters")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ BanService: No authenticated user")
            throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        print("✅ BanService: User authenticated - \(userId)")
        
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ BanService: Appeal reason is empty")
            throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Appeal reason cannot be empty"])
        }
        
        // Verify user document exists before submitting
        print("🔍 BanService: Checking if user document exists...")
        let userDoc = try await db.collection(usersCollection).document(userId).getDocument()
        if !userDoc.exists {
            print("❌ BanService: User document does not exist for \(userId)")
            Logger.error("User document does not exist for \(userId)", service: "BanService")
            throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Your account information could not be found. Please contact support."])
        }
        
        print("✅ BanService: User document exists")
        if let userData = userDoc.data() {
            let isBanned = userData["isBanned"] as? Bool ?? false
            print("   User isBanned: \(isBanned)")
        }
        
        print("📞 BanService: Calling Firebase function 'submitBanAppeal'...")
        let function = functions.httpsCallable("submitBanAppeal")
        
        do {
            print("📤 BanService: Sending function call with reason: \(reason.prefix(50))...")
            let result = try await function.call([
                "reason": reason
            ])
            
            print("📥 BanService: Received response from function")
            print("   Response data type: \(type(of: result.data))")
            
            guard let data = result.data as? [String: Any] else {
                print("❌ BanService: Response data is not a dictionary")
                print("   Actual data: \(result.data ?? "nil")")
                throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }
            
            print("✅ BanService: Response is a dictionary")
            print("   Response keys: \(data.keys.joined(separator: ", "))")
            
            guard let appealId = data["appealId"] as? String else {
                print("❌ BanService: appealId not found in response")
                print("   Response data: \(data)")
                throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }
            
            print("✅ BanService: Appeal submitted successfully! Appeal ID: \(appealId)")
            Logger.info("Ban appeal submitted: \(appealId)", service: "BanService")
            return appealId
        } catch let error as NSError {
            Logger.error("Error submitting appeal", service: "BanService")
            Logger.error("   Error domain: \(error.domain)", service: "BanService")
            Logger.error("   Error code: \(error.code)", service: "BanService")
            Logger.error("   Error description: \(error.localizedDescription)", service: "BanService")
            Logger.error("   Error userInfo: \(error.userInfo)", service: "BanService")
            
            // Check if it's a Firebase Functions error
            // Firebase Functions errors can be in different domains
            if error.domain == "FIRFunctionsErrorDomain" || error.domain == "com.firebase.functions" {
                // Extract the error message from the userInfo
                let errorMessage = error.userInfo["NSLocalizedDescription"] as? String ?? error.localizedDescription
                
                // Handle specific error codes
                // Note: Firebase Functions error codes can be positive or negative depending on the domain
                let errorCode = error.code
                print("   Firebase Functions error code: \(errorCode)")
                
                switch errorCode {
                case -1, 14: // UNAVAILABLE
                    Logger.error("Service unavailable: \(errorMessage)", service: "BanService")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service temporarily unavailable. Please check your internet connection and try again."])
                case -2, 4: // DEADLINE_EXCEEDED
                    Logger.error("Request timed out: \(errorMessage)", service: "BanService")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
                case -3, 5: // NOT_FOUND
                    Logger.error("Function not found: \(errorMessage)", service: "BanService")
                    print("   ⚠️ The Firebase function 'submitBanAppeal' is not deployed or not found.")
                    print("   Please deploy the Firebase functions to fix this issue.")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "The appeal submission service is not available. Please contact support or try again later."])
                case -4, 6: // ALREADY_EXISTS
                    Logger.error("Appeal already exists: \(errorMessage)", service: "BanService")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You already have a pending appeal. Please wait for it to be reviewed."])
                case -5, 7: // PERMISSION_DENIED
                    Logger.error("Permission denied: \(errorMessage)", service: "BanService")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please sign in again."])
                case -6, 16: // UNAUTHENTICATED
                    Logger.error("Not authenticated: \(errorMessage)", service: "BanService")
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."])
                default:
                    Logger.error("Firebase function error (\(errorCode)): \(errorMessage)", service: "BanService")
                    // Try to extract a more specific error message
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        let underlyingMessage = underlyingError.localizedDescription
                        throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: underlyingMessage])
                    }
                    throw NSError(domain: "BanService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            } else {
                // Re-throw other errors as-is
                Logger.error("Error submitting appeal: \(error.localizedDescription)", service: "BanService")
                throw error
            }
        }
    }
    
    /// Get current user's ban appeal
    func getCurrentAppeal() async throws -> BanAppeal? {
        guard let userId = Auth.auth().currentUser?.uid else {
            return nil
        }
        
        let snapshot = try await db.collection(banAppealsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "submittedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        var appeal = try document.data(as: BanAppeal.self)
        appeal.id = document.documentID
        return appeal
    }
    
    /// Get all appeals for current user
    func getUserAppeals() async throws -> [BanAppeal] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        let snapshot = try await db.collection(banAppealsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "submittedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { doc in
            var appeal = try doc.data(as: BanAppeal.self)
            appeal.id = doc.documentID
            return appeal
        }
    }
}

