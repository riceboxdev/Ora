//
//  ToastNotificationView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/7/25.
//

import SwiftUI

struct ToastNotificationView: View {
    let notification: Notification
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    /// Get primary actor profile photo URL
    private func getPrimaryActorPhotoUrl() -> String? {
        return notification.actors.first?.profilePhotoUrl
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile photo (from first actor)
                if let profilePhotoUrl = getPrimaryActorPhotoUrl(), !profilePhotoUrl.isEmpty {
                    AsyncImage(url: URL(string: profilePhotoUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                }
                
                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(notification.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Post preview thumbnail (if available)
                if let imageUrl = notification.postThumbnailUrl ?? notification.postImageUrl,
                   !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct ToastNotificationModifier: ViewModifier {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var selectedTab: Int
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            // Show toast only if not on notifications tab (tag 2)
            if notificationManager.showToast,
               let toastNotification = notificationManager.toastNotification,
               selectedTab != 2 {
                ToastNotificationView(
                    notification: toastNotification,
                    onDismiss: {
                        notificationManager.dismissToast()
                    },
                    onTap: {
                        // Navigate to notifications tab
                        selectedTab = 2
                        notificationManager.dismissToast()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notificationManager.showToast)
            }
        }
    }
}

extension View {
    func toastNotifications(notificationManager: NotificationManager, selectedTab: Binding<Int>) -> some View {
        modifier(ToastNotificationModifier(notificationManager: notificationManager, selectedTab: selectedTab))
    }
}

