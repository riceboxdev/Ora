//
//  NotificationPreferences.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import Foundation
import FirebaseFirestore

struct NotificationPreferences: Codable {
    var pushEnabled: Bool
    var emailEnabled: Bool
    var engagement: EngagementPreferences
    var system: SystemPreferences
    var promotional: PromotionalPreferences
    var quietHours: QuietHours
    
    struct EngagementPreferences: Codable {
        var likes: Bool
        var comments: Bool
        var follows: Bool
        var mentions: Bool
        var saves: Bool
        var shares: Bool
        var reposts: Bool
    }
    
    struct SystemPreferences: Codable {
        var postModeration: Bool
        var accountActions: Bool
    }
    
    struct PromotionalPreferences: Codable {
        var enabled: Bool  // Opt-in for promotional notifications
        var announcements: Bool
        var promos: Bool
        var featureUpdates: Bool
        var events: Bool
    }
    
    struct QuietHours: Codable {
        var enabled: Bool
        var startTime: String  // "22:00"
        var endTime: String     // "08:00"
    }
    
    static var `default`: NotificationPreferences {
        NotificationPreferences(
            pushEnabled: true,
            emailEnabled: false,
            engagement: EngagementPreferences(
                likes: true,
                comments: true,
                follows: true,
                mentions: true,
                saves: true,
                shares: true,
                reposts: true
            ),
            system: SystemPreferences(
                postModeration: true,
                accountActions: true
            ),
            promotional: PromotionalPreferences(
                enabled: false,  // Opt-in by default
                announcements: false,
                promos: false,
                featureUpdates: false,
                events: false
            ),
            quietHours: QuietHours(
                enabled: false,
                startTime: "22:00",
                endTime: "08:00"
            )
        )
    }
    
    /// Create NotificationPreferences from Firestore document
    static func from(document: DocumentSnapshot) -> NotificationPreferences? {
        guard var data = document.data() else {
            return nil
        }
        
        // Convert Firestore Timestamps to milliseconds for JSON serialization
        // This prevents "Invalid type in JSON write (FIRTimestamp)" error
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            data["createdAt"] = Int(createdAtTimestamp.dateValue().timeIntervalSince1970 * 1000)
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            data["updatedAt"] = Int(updatedAtTimestamp.dateValue().timeIntervalSince1970 * 1000)
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoder = JSONDecoder()
            return try decoder.decode(NotificationPreferences.self, from: jsonData)
        } catch {
            print("Error decoding NotificationPreferences: \(error)")
            return nil
        }
    }
}













