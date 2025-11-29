//
//  AnnouncementView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/26/25.
//

import SwiftUI
import FirebaseAuth

struct AnnouncementView: View {
    let announcements: [Announcement]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var announcementService = AnnouncementService()
    @State private var currentAnnouncementIndex = 0
    @State private var currentPageIndex = 0
    @State private var isMarkingViewed = false
    
    init(announcements: [Announcement]) {
        self.announcements = announcements
        print("📢 AnnouncementView: Initialized with \(announcements.count) announcement(s)")
        for (index, announcement) in announcements.enumerated() {
            print("📢 AnnouncementView: Announcement \(index): '\(announcement.title)' with \(announcement.pages.count) page(s)")
        }
    }
    
    var currentAnnouncement: Announcement? {
        guard currentAnnouncementIndex < announcements.count else { return nil }
        return announcements[currentAnnouncementIndex]
    }
    
    var currentPage: AnnouncementPage? {
        guard let announcement = currentAnnouncement,
              currentPageIndex < announcement.pages.count else { return nil }
        return announcement.pages[currentPageIndex]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Grid lines background (matching onboarding style)
                gridLinesBackground()
                
                if let announcement = currentAnnouncement, let page = currentPage {
                    VStack(spacing: 20) {
                        
                        // Page indicator (if multiple pages) - matching onboarding step counter style
                        if announcement.pages.count > 1 {
                            VStack(spacing: 4) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        Capsule()
                                            .fill(Color.primary.opacity(0.2))
                                            .frame(height: 4)
                                        
                                        // Progress
                                        Capsule()
                                            .fill(Color.primary)
                                            .frame(width: geometry.size.width * CGFloat(currentPageIndex + 1) / CGFloat(announcement.pages.count), height: 4)
                                            .animation(.spring(response: 0.3), value: currentPageIndex)
                                    }
                                }
                                .frame(height: 4)
                                
                                Text("Page \(currentPageIndex + 1) of \(announcement.pages.count)")
                                    .font(.creatoDisplayCaption())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                // Page Image
                                HStack {
                                    if let imageUrl = page.imageUrl, !imageUrl.isEmpty {
                                        AsyncImage(url: URL(string: imageUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(height: 200)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(maxHeight: 300)
                                                    .cornerRadius(12)
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(.secondary)
                                                    .frame(height: 200)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(height: 80)
                                        .padding(.horizontal)
                                    }
                                    Spacer()
                                }
                                
                                // Announcement Title
                                Text(announcement.title)
                                    .font(.creatoDisplayTitle())
                                    .padding(.horizontal)
                                    .hLeading()
                                
                                // Page Title (if different from announcement title)
                                if let pageTitle = page.title, !pageTitle.isEmpty {
                                    Text(pageTitle)
                                        .font(.creatoDisplayHeadline())
                                        .padding(.horizontal)
                                        .hLeading()
                                }
                                
                                // Page Body
                                Text(page.body)
                                    .font(.creatoDisplayBody())
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Previous Page Button
                                if currentPageIndex > 0 {
                                    Button(action: {
                                        withAnimation {
                                            currentPageIndex -= 1
                                        }
                                    }) {
                                        Text("Previous")
                                            .font(.creatoDisplayHeadline())
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(10)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                // Next/Done Button
                                Button(action: {
                                    if currentPageIndex < announcement.pages.count - 1 {
                                        // Go to next page
                                        withAnimation {
                                            currentPageIndex += 1
                                        }
                                    } else {
                                        // Move to next announcement or dismiss
                                        handleNextAnnouncement()
                                    }
                                }) {
                                    Text(currentPageIndex < announcement.pages.count - 1 ? "Next" : 
                                         currentAnnouncementIndex < announcements.count - 1 ? "Next Announcement" : "Done")
                                        .font(.creatoDisplayHeadline())
                                        .foregroundColor(.whiteui)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                }
                                .buttonStyle(.glassProminent)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        print("📢 AnnouncementView: View appeared - announcement: \(announcement.title), page index: \(currentPageIndex)")
                        print("📢 AnnouncementView: Page body length: \(page.body.count)")
                        print("📢 AnnouncementView: Page title: '\(page.title ?? "nil")'")
                        print("📢 AnnouncementView: Page imageUrl: '\(page.imageUrl ?? "nil")'")
                    }
                } else {
                    // Loading or empty state
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading announcement...")
                            .font(.creatoDisplayBody())
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        print("📢 AnnouncementView: Empty state - announcements count: \(announcements.count)")
                        print("📢 AnnouncementView: Current index: \(currentAnnouncementIndex)")
                        print("📢 AnnouncementView: currentAnnouncement is nil: \(currentAnnouncement == nil)")
                        print("📢 AnnouncementView: currentPage is nil: \(currentPage == nil)")
                        if let announcement = currentAnnouncement {
                            print("📢 AnnouncementView: Current announcement: \(announcement.title), pages: \(announcement.pages.count)")
                            print("📢 AnnouncementView: currentPageIndex: \(currentPageIndex)")
                            for (index, page) in announcement.pages.enumerated() {
                                print("📢 AnnouncementView: Page \(index): body='\(page.body)', title=\(page.title ?? "nil")")
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Task {
                            await markCurrentAnnouncementViewed()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                print("📢 AnnouncementView: Task started")
                print("📢 AnnouncementView: announcements.count = \(announcements.count)")
                print("📢 AnnouncementView: currentAnnouncementIndex = \(currentAnnouncementIndex)")
                print("📢 AnnouncementView: currentAnnouncement = \(currentAnnouncement?.title ?? "nil")")
                print("📢 AnnouncementView: currentPage = \(currentPage != nil ? "exists" : "nil")")
                // Mark first announcement as viewed when shown
                await markCurrentAnnouncementViewed()
            }
            .onAppear {
                print("📢 AnnouncementView: Body onAppear - announcements: \(announcements.count)")
            }
        }
    }
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.6),
                    .init(color: .white.opacity(0.3), location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
    
    private func handleNextAnnouncement() {
        // Mark current announcement as viewed
        Task {
            await markCurrentAnnouncementViewed()
        }
        
        // Move to next announcement
        if currentAnnouncementIndex < announcements.count - 1 {
            withAnimation {
                currentAnnouncementIndex += 1
                currentPageIndex = 0
            }
            // Mark new announcement as viewed
            Task {
                await markCurrentAnnouncementViewed()
            }
        } else {
            // All announcements shown, dismiss
            dismiss()
        }
    }
    
    private func markCurrentAnnouncementViewed() async {
        guard let userId = authViewModel.currentUser?.uid,
              let announcement = currentAnnouncement,
              let announcementId = announcement.id else {
            return
        }
        
        guard !isMarkingViewed else { return }
        isMarkingViewed = true
        
        do {
            try await announcementService.markAnnouncementViewed(
                announcementId: announcementId,
                userId: userId,
                version: announcement.version
            )
            print("✅ Marked announcement \(announcementId) as viewed")
        } catch {
            print("❌ Error marking announcement as viewed: \(error)")
        }
        
        isMarkingViewed = false
    }
}

#Preview {
    AnnouncementView(announcements: [
        Announcement(
            title: "Welcome to Ora!",
            pages: [
                AnnouncementPage(
                    title: "New Features",
                    body: "We've added some amazing new features for you to explore.",
                    imageUrl: "https://imagedelivery.net/-U9fBlv98S0Bl-wUpX9XJw/317d6b2f-aa53-4841-c40f-eaf5eafdea00/public",
                    layout: "default"
                )
            ],
            targetAudience: Announcement.TargetAudience(type: .all, filters: nil),
            status: .active,
            createdBy: "admin",
            version: 1
        )
    ])
    .environmentObject(AuthViewModel())
}

