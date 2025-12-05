//
//  NotificationManager.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/7/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import UIKit
import UserNotifications

// Make sure FirebaseFirestore is available - check if we need FirestoreSwift
// If the module isn't found, we may need to add it to the project dependencies

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [Notification] = []
    @Published var unreadCount: Int = 0
    @Published var showToast: Bool = false
    @Published var toastNotification: Notification?
    
    private var listener: ListenerRegistration?
    private var userId: String?
    private let db = Firestore.firestore()
    private var hasInitialLoad = false // Track if we've done initial load
    private var isAppInForeground = false // Track app state
    
    private init() {
        // Private initializer for singleton
        setupAppStateObserver()
    }
    
    /// Setup observer for app state changes
    private func setupAppStateObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppInForeground = true
            Logger.info("App became active", service: "NotificationManager")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppInForeground = false
            Logger.info("App will resign active", service: "NotificationManager")
        }
        
        // Set initial state
        isAppInForeground = UIApplication.shared.applicationState == .active
        Logger.info("Initial app state - \(isAppInForeground ? "foreground" : "background")", service: "NotificationManager")
    }
    
    /// Start listening to notifications for a user
    func startListening(userId: String) {
        // Stop any existing listener
        stopListening()
        
        self.userId = userId
        self.hasInitialLoad = false // Reset initial load flag
        
        Logger.info("Starting Firestore listener for user \(userId)", service: "NotificationManager")
        
        let notificationsRef = db
            .collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
        
        listener = notificationsRef.addSnapshotListener { [weak self] querySnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.error("Error listening to notifications: \(error.localizedDescription)", service: "NotificationManager")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    Logger.warning("No documents in snapshot", service: "NotificationManager")
                    return
                }
                
                Logger.info("Received \(documents.count) notifications from Firestore", service: "NotificationManager")
                
                // Convert documents to Notification models
                var loadedNotifications: [Notification] = []
                for document in documents {
                    if let notification = Notification.from(document: document) {
                        loadedNotifications.append(notification)
                    }
                }
                
                // Update state
                self.notifications = loadedNotifications
                self.unreadCount = loadedNotifications.filter { !$0.isRead }.count
                
                Logger.info("Updated notifications (\(loadedNotifications.count) total, \(self.unreadCount) unread)", service: "NotificationManager")
                
                // Check for new notifications to show toast (only when app is in foreground and after initial load)
                if self.hasInitialLoad,
                   self.isAppInForeground,
                   let lastChange = querySnapshot?.documentChanges.last,
                   lastChange.type == .added,
                   let newNotification = Notification.from(document: lastChange.document) {
                    self.toastNotification = newNotification
                    self.showToast = true
                    
                    Logger.info("Showing toast for new notification (app in foreground)", service: "NotificationManager")
                    
                    // Auto-dismiss toast after 4 seconds
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        self.showToast = false
                    }
                } else if let lastChange = querySnapshot?.documentChanges.last,
                         lastChange.type == .added {
                    Logger.debug("New notification received but not showing toast (initial load: \(!self.hasInitialLoad), app in foreground: \(self.isAppInForeground))", service: "NotificationManager")
                }
                
                // Mark initial load as complete after first successful fetch
                if !self.hasInitialLoad {
                    self.hasInitialLoad = true
                    Logger.info("Initial load complete, will show toasts for new notifications", service: "NotificationManager")
                }
            }
        }
    }
    
    /// Stop listening to notifications
    func stopListening() {
        Logger.info("Stopping Firestore listener", service: "NotificationManager")
        listener?.remove()
        listener = nil
        userId = nil
        hasInitialLoad = false // Reset initial load flag
        notifications = []
        unreadCount = 0
    }
    
    /// Load notifications (one-time fetch)
    func loadNotifications() async {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("No user ID available", service: "NotificationManager")
            return
        }
        
        Logger.info("Loading notifications for user \(userId)", service: "NotificationManager")
        
        do {
            let notificationsRef = db
                .collection("users")
                .document(userId)
                .collection("notifications")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
            
            let snapshot = try await notificationsRef.getDocuments()
            
            var loadedNotifications: [Notification] = []
            for document in snapshot.documents {
                if let notification = Notification.from(document: document) {
                    loadedNotifications.append(notification)
                }
            }
            
            notifications = loadedNotifications
            unreadCount = loadedNotifications.filter { !$0.isRead }.count
            
            Logger.info("Loaded \(notifications.count) notifications (\(unreadCount) unread)", service: "NotificationManager")
        } catch {
            Logger.error("Error loading notifications: \(error.localizedDescription)", service: "NotificationManager")
        }
    }
    
    /// Mark a notification as read
    func markAsRead(notificationId: String) async {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("No user ID available", service: "NotificationManager")
            return
        }
        
        Logger.info("Marking notification \(notificationId) as read", service: "NotificationManager")
        
        do {
            let notificationRef = db
                .collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
            
            try await notificationRef.updateData([
                "isRead": true,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            Logger.info("Notification marked as read", service: "NotificationManager")
            
            // Update local state
            // Since we're using Firestore listener, it will update automatically
            // But we can update unread count immediately if notification exists
            if notifications.contains(where: { $0.id == notificationId }) {
                    unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            Logger.error("Error marking notification as read: \(error.localizedDescription)", service: "NotificationManager")
        }
    }
    
    /// Mark all notifications as read
    func markAllAsRead() async {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else {
            Logger.warning("No user ID available", service: "NotificationManager")
            return
        }
        
        Logger.info("Marking all notifications as read", service: "NotificationManager")
        
        do {
            let notificationsRef = db
                .collection("users")
                .document(userId)
                .collection("notifications")
                .whereField("isRead", isEqualTo: false)
            
            let snapshot = try await notificationsRef.getDocuments()
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.updateData([
                    "isRead": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: document.reference)
            }
            
            try await batch.commit()
            
            Logger.info("All notifications marked as read", service: "NotificationManager")
            
            // Update local state
            unreadCount = 0
            
            // Clear iOS badge count
            await UIApplication.shared.applicationIconBadgeNumber = 0
            try await UNUserNotificationCenter.current().setBadgeCount(0)
        } catch {
            Logger.error("Error marking all notifications as read: \(error.localizedDescription)", service: "NotificationManager")
        }
    }
    
    /// Dismiss toast
    func dismissToast() {
        showToast = false
        toastNotification = nil
    }
}
