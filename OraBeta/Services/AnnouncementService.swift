//
//  AnnouncementService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/26/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class AnnouncementService: ObservableObject {
    private let db = Firestore.firestore()
    private let announcementsCollection = "announcements"
    private let announcementViewsCollection = "announcement_views"
    private let usersCollection = "users"
    private let postsCollection = "posts"
    
    private let profileService: ProfileServiceProtocol
    
    init(profileService: ProfileServiceProtocol? = nil) {
        self.profileService = profileService ?? ProfileService()
    }
    
    /// Fetch active announcements that the user should see
    func fetchActiveAnnouncements(for userId: String) async throws -> [Announcement] {
        // Fetch all active announcements
        let snapshot = try await db.collection(announcementsCollection)
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        let allAnnouncements = try snapshot.documents.compactMap { doc -> Announcement? in
            var announcement = try doc.data(as: Announcement.self)
            announcement.id = doc.documentID
            return announcement
        }
        
        // Filter announcements that user should see
        var eligibleAnnouncements: [Announcement] = []
        
        for announcement in allAnnouncements {
            // Check if user matches audience
            let matchesAudience = try await userMatchesAudience(
                userId: userId,
                audience: announcement.targetAudience
            )
            
            if matchesAudience {
                // Check if user has already seen this version
                let shouldShow = try await shouldShowAnnouncement(
                    announcement: announcement,
                    userId: userId
                )
                
                if shouldShow {
                    eligibleAnnouncements.append(announcement)
                }
            }
        }
        
        return eligibleAnnouncements
    }
    
    /// Check if user matches the announcement audience criteria
    private func userMatchesAudience(
        userId: String,
        audience: Announcement.TargetAudience
    ) async throws -> Bool {
        switch audience.type {
        case .all:
            return true
            
        case .role:
            guard let role = audience.filters?.role else { return false }
            guard let profile = try await profileService.getUserProfile(userId: userId) else {
                return false
            }
            
            switch role {
            case "admin":
                return profile.isAdmin
            case "user":
                return !profile.isAdmin
            case "moderator":
                // For now, moderators are treated as admins
                return profile.isAdmin
            default:
                return false
            }
            
        case .activity:
            guard let days = audience.filters?.days else { return false }
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let cutoffTimestamp = Timestamp(date: cutoffDate)
            
            // Check if user has created posts in the last N days
            let postsSnapshot = try await db.collection(postsCollection)
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: cutoffTimestamp)
                .limit(to: 1)
                .getDocuments()
            
            return !postsSnapshot.documents.isEmpty
            
        case .custom:
            guard let userIds = audience.filters?.userIds else { return false }
            return userIds.contains(userId)
            
        case .segment:
            // Future: implement segment matching
            // For now, return false
            return false
        }
    }
    
    /// Check if announcement should be shown to user
    /// Returns true if user hasn't seen it, or if the version has been updated
    func shouldShowAnnouncement(
        announcement: Announcement,
        userId: String
    ) async throws -> Bool {
        guard let announcementId = announcement.id else { return false }
        
        // Check if user has viewed this announcement
        let viewSnapshot = try await db.collection(announcementViewsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("announcementId", isEqualTo: announcementId)
            .limit(to: 1)
            .getDocuments()
        
        guard let viewDoc = viewSnapshot.documents.first else {
            // User hasn't seen it yet
            return true
        }
        
        let viewedVersion = try viewDoc.data()["viewedVersion"] as? Int ?? 0
        
        // Show if announcement version is newer than what user viewed
        return announcement.version > viewedVersion
    }
    
    /// Mark announcement as viewed by user
    func markAnnouncementViewed(
        announcementId: String,
        userId: String,
        version: Int
    ) async throws {
        let viewData: [String: Any] = [
            "userId": userId,
            "announcementId": announcementId,
            "viewedAt": FieldValue.serverTimestamp(),
            "viewedVersion": version,
            "dismissed": false
        ]
        
        // Use document ID combining userId and announcementId for uniqueness
        let viewId = "\(userId)_\(announcementId)"
        try await db.collection(announcementViewsCollection)
            .document(viewId)
            .setData(viewData, merge: true)
    }
}

