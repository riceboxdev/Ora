//
//  EditProfileView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI
import PhotosUI
import Toasts

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentToast) var presentToast
    var profileService: ProfileService
    @State var profile: UserProfile
    
    @State private var username: String
    @State private var bio: String
    @State private var websiteLink: String
    @State private var location: String
    @State private var socialLinks: [String: String]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSocialLink = false
    @State private var selectedPlatform = "Twitter"
    @State private var socialLinkURL = ""
    
    // Profile photo upload
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhoto: UIImage?
    @State private var isUploadingPhoto = false
    
    private let imageUploadService = ImageUploadService()
    
    private let availablePlatforms = ["Twitter", "Instagram", "Facebook", "LinkedIn", "TikTok", "YouTube", "Snapchat", "Pinterest"]
    
    init(profile: UserProfile, profileService: ProfileService) {
        self.profileService = profileService
        self._profile = State(initialValue: profile)
        self._username = State(initialValue: profile.username)
        self._bio = State(initialValue: profile.bio ?? "")
        self._websiteLink = State(initialValue: profile.websiteLink ?? "")
        self._location = State(initialValue: profile.location ?? "")
        self._socialLinks = State(initialValue: profile.socialLinks ?? [:])
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Picture Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            // Profile Picture
                            ZStack(alignment: .bottomTrailing) {
                                if let selectedPhoto = selectedPhoto {
                                    Image(uiImage: selectedPhoto)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                                } else {
                                    AsyncImage(url: URL(string: profile.profilePhotoUrl ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                                }
                                
                                // Camera icon button
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                                .disabled(isUploadingPhoto || isLoading)
                            }
                            
                            if isUploadingPhoto {
                                ProgressView("Uploading...")
                                    .font(.caption)
                            } else if selectedPhoto != nil {
                                Text("New photo selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Basic Information")) {
                    TextField("Username", text: $username)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Website", text: $websiteLink)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("Location", text: $location)
                }
                
                Section(header: Text("Social Links")) {
                    ForEach(Array(socialLinks.keys.sorted()), id: \.self) { platform in
                        HStack {
                            Text(platform)
                                .font(.subheadline)
                            Spacer()
                            Text(socialLinks[platform] ?? "")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                            Button(action: {
                                editSocialLink(platform: platform)
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                removeSocialLink(platform: platform)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        showingAddSocialLink = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Social Link")
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let newValue = newValue {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedPhoto = image
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSocialLink) {
                AddSocialLinkSheet(
                    selectedPlatform: $selectedPlatform,
                    socialLinkURL: $socialLinkURL,
                    availablePlatforms: availablePlatforms,
                    existingPlatforms: Array(socialLinks.keys),
                    onSave: { platform, url in
                        addSocialLink(platform: platform, url: url)
                    },
                    onDismiss: {
                        // Reset fields when dismissed
                        selectedPlatform = availablePlatforms.first ?? "Twitter"
                        socialLinkURL = ""
                    }
                )
            }
        }
    }
    
    private func addSocialLink(platform: String, url: String) {
        if !url.isEmpty {
            socialLinks[platform] = url
            selectedPlatform = availablePlatforms.first ?? "Twitter"
            socialLinkURL = ""
        }
    }
    
    private func editSocialLink(platform: String) {
        selectedPlatform = platform
        socialLinkURL = socialLinks[platform] ?? ""
        showingAddSocialLink = true
    }
    
    private func removeSocialLink(platform: String) {
        socialLinks.removeValue(forKey: platform)
    }
    
    private func saveProfile() async {
        print("📝 EditProfileView: saveProfile() called")
        print("   Current profile ID: \(profile.id ?? "nil")")
        print("   Username: \(username)")
        print("   Has selected photo: \(selectedPhoto != nil)")
        
        isLoading = true
        errorMessage = nil
        
        var updatedProfile = profile
        
        // Upload new profile photo if selected
        if let selectedPhoto = selectedPhoto {
            print("📸 EditProfileView: Uploading new profile photo...")
            isUploadingPhoto = true
            do {
                guard let userId = profile.id else {
                    print("❌ EditProfileView: User ID not found")
                    errorMessage = "User ID not found"
                    isLoading = false
                    isUploadingPhoto = false
                    return
                }
                print("   User ID: \(userId)")
                print("   Image size: \(selectedPhoto.size)")
                
                let (imageUrl, _) = try await imageUploadService.uploadImage(selectedPhoto, userId: userId)
                updatedProfile.profilePhotoUrl = imageUrl
                print("✅ EditProfileView: Profile photo uploaded: \(imageUrl)")
            } catch {
                print("❌ EditProfileView: Failed to upload photo: \(error)")
                print("   Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain)")
                    print("   Code: \(nsError.code)")
                }
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                isLoading = false
                isUploadingPhoto = false
                return
            }
            isUploadingPhoto = false
        }
        
        // Update profile fields
        updatedProfile.username = username
        updatedProfile.bio = bio.isEmpty ? nil : bio
        updatedProfile.websiteLink = websiteLink.isEmpty ? nil : websiteLink
        updatedProfile.location = location.isEmpty ? nil : location
        updatedProfile.socialLinks = socialLinks.isEmpty ? nil : socialLinks
        
        print("📝 EditProfileView: Saving profile to Firestore...")
        print("   Username: \(updatedProfile.username)")
        print("   Bio: \(updatedProfile.bio ?? "nil")")
        print("   Website: \(updatedProfile.websiteLink ?? "nil")")
        print("   Location: \(updatedProfile.location ?? "nil")")
        print("   Profile photo URL: \(updatedProfile.profilePhotoUrl ?? "nil")")
        print("   Social links count: \(updatedProfile.socialLinks?.count ?? 0)")
        
        do {
            try await profileService.saveUserProfile(updatedProfile)
            print("✅ EditProfileView: Profile saved successfully!")
            
            // Show success toast
            let toast = ToastValue(
                icon: Image(systemName: "checkmark.circle.fill"),
                message: "Profile Updated!"
            )
            presentToast(toast)
            
            // Delay dismiss to show toast
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            print("   Dismissing view...")
            dismiss()
        } catch {
            print("❌ EditProfileView: Failed to save profile")
            print("   Error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   User info: \(nsError.userInfo)")
            }
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
        print("📝 EditProfileView: saveProfile() completed, isLoading set to false")
    }
}

struct AddSocialLinkSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPlatform: String
    @Binding var socialLinkURL: String
    let availablePlatforms: [String]
    let existingPlatforms: [String]
    let onSave: (String, String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Platform")) {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(availablePlatforms, id: \.self) { platform in
                            Text(platform).tag(platform)
                        }
                    }
                }
                
                Section(header: Text("URL")) {
                    TextField("https://...", text: $socialLinkURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(existingPlatforms.contains(selectedPlatform) ? "Edit Social Link" : "Add Social Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedPlatform, socialLinkURL)
                        onDismiss()
                        dismiss()
                    }
                    .disabled(socialLinkURL.isEmpty)
                }
            }
        }
    }
}

#Preview {
    EditProfileView(
        profile: UserProfile(
            email: "test@example.com",
            username: "testuser",
            bio: "Test bio",
            isAdmin: false
        ),
        profileService: ProfileService()
    )
}

