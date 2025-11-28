//
//  PreferencesView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct PreferencesView: View {
    private let contentFilterService = ContentFilterService()
    private let discoveryService = DiscoveryPreferencesService()
    private let profileService = ProfileService()
    
    @State private var accountSettings: AccountSettings?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAdmin = false
    
    var body: some View {
        List {
            // Language Section
            Section(
                header: Text("Language")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if let settings = accountSettings {
                    Picker("Preferred Language", selection: Binding(
                        get: { settings.preferredLanguage ?? "en" },
                        set: { newValue in
                            Task {
                                do {
                                    try await discoveryService.updatePreferredLanguage(newValue == "en" ? nil : newValue)
                                    await loadSettings()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    )) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Japanese").tag("ja")
                        Text("Chinese").tag("zh")
                    }
                    .font(.creatoDisplayBody())
                }
            }
            
            // Content Filters Section
            Section(
                header: Text("Content Filters")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                if let settings = accountSettings {
                    Toggle("Mature Content Filter", isOn: Binding(
                        get: { settings.matureContentFilter },
                        set: { newValue in
                            Task {
                                do {
                                    try await contentFilterService.updateMatureContentFilter(newValue)
                                    await loadSettings()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    ))
                    .font(.creatoDisplayBody())
                    
                    if let blockedTags = settings.blockedTags, !blockedTags.isEmpty {
                        ForEach(blockedTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .font(.creatoDisplayBody())
                                Spacer()
                                Button(action: {
                                    Task {
                                        do {
                                            try await contentFilterService.removeBlockedTag(tag)
                                            await loadSettings()
                                        } catch {
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    NavigationLink {
                        AddBlockedTagView(
                            contentFilterService: contentFilterService,
                            onAdd: {
                                Task {
                                    await loadSettings()
                                }
                            }
                        )
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Blocked Tag")
                                .font(.creatoDisplayBody())
                        }
                    }
                }
            }
            
            // Discovery Preferences Section (Admin Only)
            if isAdmin {
                Section(
                    header: Text("Discovery Preferences")
                        .font(.creatoDisplayCaption(.medium))
                        .foregroundColor(.secondary)
                        .textCase(nil)
                ) {
                    if let settings = accountSettings {
                        Picker("Algorithm Preference", selection: Binding(
                            get: { settings.algorithmPreference },
                            set: { newValue in
                                Task {
                                    do {
                                        try await discoveryService.updateAlgorithmPreference(newValue)
                                        await loadSettings()
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        )) {
                            Text("Personalized").tag("personalized")
                            Text("Trending").tag("trending")
                            Text("Balanced").tag("balanced")
                        }
                        .font(.creatoDisplayBody())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personalized Weight: \(Int(settings.personalizedWeight * 100))%")
                                .font(.creatoDisplayCaption())
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: Binding(
                                    get: { settings.personalizedWeight },
                                    set: { newValue in
                                        let trendingWeight = 1.0 - newValue
                                        Task {
                                            do {
                                                try await discoveryService.updateWeights(
                                                    personalizedWeight: newValue,
                                                    trendingWeight: trendingWeight
                                                )
                                                await loadSettings()
                                            } catch {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    }
                                ),
                                in: 0...1,
                                step: 0.1
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkAdminStatus()
            await loadSettings()
        }
    }
    
    private func checkAdminStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isAdmin = false
            return
        }
        
        do {
            isAdmin = try await profileService.isAdmin(userId: userId)
        } catch {
            print("❌ PreferencesView: Failed to check admin status: \(error)")
            isAdmin = false
        }
    }
    
    private func loadSettings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            accountSettings = try await contentFilterService.getAccountSettings()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ PreferencesView: Failed to load settings: \(error)")
        }
        
        isLoading = false
    }
}

struct AddBlockedTagView: View {
    @Environment(\.dismiss) var dismiss
    let contentFilterService: ContentFilterService
    let onAdd: () -> Void
    
    @State private var tag = ""
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            Section(
                header: Text("Tag")
                    .font(.creatoDisplayCaption(.medium))
                    .foregroundColor(.secondary)
                    .textCase(nil)
            ) {
                TextField("Enter tag to block", text: $tag)
                    .font(.creatoDisplayBody())
                    .autocapitalization(.none)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Add Blocked Tag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.creatoDisplayBody())
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    Task {
                        do {
                            try await contentFilterService.addBlockedTag(tag)
                            onAdd()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .font(.creatoDisplayBody())
                .disabled(tag.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
}

