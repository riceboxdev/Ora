//
//  NotificationsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct NotificationsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading && notificationManager.notifications.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if notificationManager.notifications.isEmpty {
                    Text("No notifications")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(notificationManager.notifications) { notification in
                        NotificationRow(notification: notification)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                Task {
                                    if let notificationId = notification.id {
                                        await notificationManager.markAsRead(notificationId: notificationId)
                                    }
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshNotifications()
            }
            .task {
                // Refresh when view appears
                await refreshNotifications()
                // Mark all notifications as read when viewing the list
                await notificationManager.markAllAsRead()
            }
        }
    }
    
    private func refreshNotifications() async {
        isLoading = true
        await notificationManager.loadNotifications()
        isLoading = false
    }
}

struct NotificationRow: View {
    let notification: Notification
    
    /// Format relative time - don't show seconds if it's been over a minute
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            // Less than a minute - show seconds
            let seconds = Int(timeInterval)
            return "\(seconds)s"
        } else if timeInterval < 3600 {
            // Less than an hour - show minutes
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            // Less than a day - show hours
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            // More than a day - show days
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
    
    /// Get display text for actors (handles aggregation)
    private func getActorsDisplayText() -> String {
        if notification.actorCount == 1 && !notification.actors.isEmpty {
            return notification.actors[0].username
        } else if notification.actorCount == 2 && notification.actors.count >= 2 {
            return "\(notification.actors[0].username) and \(notification.actors[1].username)"
        } else if notification.actors.count >= 2 {
            let othersCount = notification.actorCount - 2
            return "\(notification.actors[0].username), \(notification.actors[1].username), and \(othersCount) \(othersCount == 1 ? "other" : "others")"
        } else if !notification.actors.isEmpty {
            let othersCount = notification.actorCount - 1
            return "\(notification.actors[0].username) and \(othersCount) \(othersCount == 1 ? "other" : "others")"
        }
        return "Someone"
    }
    
    /// Get primary actor profile photo URL
    private func getPrimaryActorPhotoUrl() -> String? {
        return notification.actors.first?.profilePhotoUrl
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar (if available)
            if let profilePhotoUrl = getPrimaryActorPhotoUrl(), !profilePhotoUrl.isEmpty {
                AsyncImage(url: URL(string: profilePhotoUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.fill")
                        .font(.title)
                        
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.title2)
                   
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Message (already formatted with actors)
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(notification.isRead ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(formatRelativeTime(notification.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Post preview image (if available)
            if let imageUrl = notification.postThumbnailUrl ?? notification.postImageUrl,
               !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NotificationsView()
        .previewAuthenticated(email: "tasha@example.com", password: "password")
}
