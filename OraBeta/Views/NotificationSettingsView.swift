//
//  NotificationSettingsView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var preferencesService = NotificationPreferencesService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSaveConfirmation = false
    
    var body: some View {
        List {
            if isLoading && preferencesService.preferences.pushEnabled == false {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else {
                // Push & Email Section
                Section(
                    header: Text("Delivery Methods")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    Toggle("Push Notifications", isOn: Binding(
                        get: { preferencesService.preferences.pushEnabled },
                        set: { newValue in
                            Task {
                                await updatePreference(\.pushEnabled, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Email Notifications", isOn: Binding(
                        get: { preferencesService.preferences.emailEnabled },
                        set: { newValue in
                            Task {
                                await updatePreference(\.emailEnabled, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                }
                
                // Engagement Notifications Section
                Section(
                    header: Text("Engagement")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil),
                    footer: Text("Get notified when others interact with your content")
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.secondary)
                ) {
                    Toggle("Likes", isOn: Binding(
                        get: { preferencesService.preferences.engagement.likes },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.likes, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Comments", isOn: Binding(
                        get: { preferencesService.preferences.engagement.comments },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.comments, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Follows", isOn: Binding(
                        get: { preferencesService.preferences.engagement.follows },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.follows, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Mentions", isOn: Binding(
                        get: { preferencesService.preferences.engagement.mentions },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.mentions, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Saves", isOn: Binding(
                        get: { preferencesService.preferences.engagement.saves },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.saves, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Shares", isOn: Binding(
                        get: { preferencesService.preferences.engagement.shares },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.shares, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Reposts", isOn: Binding(
                        get: { preferencesService.preferences.engagement.reposts },
                        set: { newValue in
                            Task {
                                await updateEngagementPreference(\.reposts, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                }
                
                // System Notifications Section
                Section(
                    header: Text("System")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil),
                    footer: Text("Important updates about your account and posts")
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.secondary)
                ) {
                    Toggle("Post Moderation", isOn: Binding(
                        get: { preferencesService.preferences.system.postModeration },
                        set: { newValue in
                            Task {
                                await updateSystemPreference(\.postModeration, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    Toggle("Account Actions", isOn: Binding(
                        get: { preferencesService.preferences.system.accountActions },
                        set: { newValue in
                            Task {
                                await updateSystemPreference(\.accountActions, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                }
                
                // Promotional Notifications Section
                Section(
                    header: Text("Promotional")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil),
                    footer: Text("Opt-in to receive updates about new features, events, and announcements")
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.secondary)
                ) {
                    Toggle("Enable Promotional Notifications", isOn: Binding(
                        get: { preferencesService.preferences.promotional.enabled },
                        set: { newValue in
                            Task {
                                await updatePromotionalPreference(\.enabled, value: newValue)
                                // If disabling, also disable all sub-options
                                if !newValue {
                                    await updatePromotionalPreference(\.announcements, value: false)
                                    await updatePromotionalPreference(\.promos, value: false)
                                    await updatePromotionalPreference(\.featureUpdates, value: false)
                                    await updatePromotionalPreference(\.events, value: false)
                                }
                            }
                        }
                    ))
                    .font(.creatoDisplayBody(.medium))
                    
                    if preferencesService.preferences.promotional.enabled {
                        Toggle("Announcements", isOn: Binding(
                            get: { preferencesService.preferences.promotional.announcements },
                            set: { newValue in
                                Task {
                                    await updatePromotionalPreference(\.announcements, value: newValue)
                                }
                            }
                        ))
                        .font(.creatoDisplayBody())
                        .padding(.leading, 16)
                        
                        Toggle("Promotions", isOn: Binding(
                            get: { preferencesService.preferences.promotional.promos },
                            set: { newValue in
                                Task {
                                    await updatePromotionalPreference(\.promos, value: newValue)
                                }
                            }
                        ))
                        .font(.creatoDisplayBody())
                        .padding(.leading, 16)
                        
                        Toggle("Feature Updates", isOn: Binding(
                            get: { preferencesService.preferences.promotional.featureUpdates },
                            set: { newValue in
                                Task {
                                    await updatePromotionalPreference(\.featureUpdates, value: newValue)
                                }
                            }
                        ))
                        .font(.creatoDisplayBody())
                        .padding(.leading, 16)
                        
                        Toggle("Events", isOn: Binding(
                            get: { preferencesService.preferences.promotional.events },
                            set: { newValue in
                                Task {
                                    await updatePromotionalPreference(\.events, value: newValue)
                                }
                            }
                        ))
                        .font(.creatoDisplayBody())
                        .padding(.leading, 16)
                    }
                }
                
                // Quiet Hours Section
                Section(
                    header: Text("Quiet Hours")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil),
                    footer: Text("Pause non-urgent notifications during these hours")
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.secondary)
                ) {
                    Toggle("Enable Quiet Hours", isOn: Binding(
                        get: { preferencesService.preferences.quietHours.enabled },
                        set: { newValue in
                            Task {
                                await updateQuietHoursPreference(\.enabled, value: newValue)
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    if preferencesService.preferences.quietHours.enabled {
                        HStack {
                            Text("Start Time")
                                .font(.creatoDisplayBody())
                            Spacer()
                            Text(formatTime(preferencesService.preferences.quietHours.startTime))
                                .font(.creatoDisplayBody())
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                        
                        HStack {
                            Text("End Time")
                                .font(.creatoDisplayBody())
                            Spacer()
                            Text(formatTime(preferencesService.preferences.quietHours.endTime))
                                .font(.creatoDisplayBody())
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                        
                        Text("Quiet hours time picker coming soon")
                            .font(.creatoDisplayCaption())
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onAppear {
            preferencesService.startListening()
        }
        .onDisappear {
            preferencesService.stopListening()
        }
    }
    
    private func loadPreferences() async {
        isLoading = true
        errorMessage = nil
        do {
            try await preferencesService.loadPreferences()
        } catch {
            errorMessage = "Failed to load preferences: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func updatePreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences, T>, value: T) async {
        do {
            try await preferencesService.updatePreference(keyPath, value: value)
            showSaveConfirmation = true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func updateEngagementPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.EngagementPreferences, T>, value: T) async {
        do {
            try await preferencesService.updateEngagementPreference(keyPath, value: value)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func updateSystemPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.SystemPreferences, T>, value: T) async {
        do {
            try await preferencesService.updateSystemPreference(keyPath, value: value)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func updatePromotionalPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.PromotionalPreferences, T>, value: T) async {
        do {
            try await preferencesService.updatePromotionalPreference(keyPath, value: value)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func updateQuietHoursPreference<T>(_ keyPath: WritableKeyPath<NotificationPreferences.QuietHours, T>, value: T) async {
        do {
            try await preferencesService.updateQuietHoursPreference(keyPath, value: value)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        // Format "22:00" to "10:00 PM"
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return timeString
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: timeString) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return timeString
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
