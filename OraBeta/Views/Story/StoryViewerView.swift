//
//  StoryViewerView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import FirebaseAuth
import SwiftUI

struct StoryViewerView: View {
    let storyItems: [StoryItem]
    /// Optional callback used when presented as an overlay instead of via Navigation/Sheet.
    let onClose: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex = 0
    @State private var scrollPosition: Int? = 0
    @State private var progress: CGFloat = 0
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var pausedTime: TimeInterval = 0

    private let storyDuration: TimeInterval = 5.0  // 5 seconds per story

    private var currentStoryItem: StoryItem? {
        guard currentIndex < storyItems.count else { return nil }
        return storyItems[currentIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background stories in a horizontally paging scroll view
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(storyItems.indices, id: \.self) { index in
                            let storyItem = storyItems[index]

                            CachedImageView(
                                url: URL(
                                    string: storyItem.post.effectiveThumbnailUrl
                                ),
                                aspectRatio: storyItem.post.aspectRatio.map {
                                    CGFloat($0)
                                },
                                downsamplingSize: CGSize(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                ),
                                contentMode: .fill
                            )
                            .clipShape(.rect(cornerRadius: 20))
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0)
                                    //                                                .scaleEffect(phase.isIdentity ? 1 : 0.75)
                                    .blur(radius: phase.isIdentity ? 0 : 10)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollPosition)

                // Gradient overlay for text visibility (non-interactive)
                LinearGradient(
                    colors: [Color.black.opacity(0.3), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Story content overlay (non-interactive so scroll works)
                VStack {
                    // Progress indicators
                    HStack(spacing: 4) {
                        ForEach(0..<storyItems.count, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index <= currentIndex
                                        ? Color.white : Color.white.opacity(0.3)
                                )
                                .frame(height: 2)
                                .animation(
                                    .linear(duration: 0.3),
                                    value: currentIndex
                                )
                        }
                    }

                    // Top bar with progress indicators and user info
                    storyTopBar

                    Spacer()

                    // Bottom content area
                    if let storyItem = currentStoryItem {
                        storyBottomContent(story: storyItem)
                    }
                }
                .padding()
                .allowsHitTesting(false)

                // Gesture handling
                //                storyGestureOverlay(geometry: geometry)
            }
            //            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                } label: {
                    Image("heart.fill")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.regularMaterial)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)

                }
                .buttonStyle(.plain)
                TextField("Comment", text: .constant(""))
                    .font(.creatoDisplayBody(.regular))
                    .frame(height: 45)
                    .padding(.horizontal)
                    .glassEffect(.regular.interactive())
            }
            .padding(.horizontal)
        }
        .background(Color.black)
//        .toolbar(.hidden, for: .tabBar)
        // Dedicated close button overlay so only its hit area blocks scroll
        .overlay(alignment: .topTrailing) {
            Button {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            startStoryProgress()
            markCurrentStoryAsViewed()
            scrollPosition = currentIndex
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: currentIndex) { _ in
            resetAndStartProgress()
            markCurrentStoryAsViewed()
            scrollPosition = currentIndex
        }
        .onChange(of: scrollPosition) { newValue in
            if let newValue {
                currentIndex = newValue
            }
        }
    }

    // MARK: - Story Top Bar

    @ViewBuilder
    private var storyTopBar: some View {
        VStack(spacing: 12) {
            // Progress indicators

            // User info
            HStack {
                // Profile photo
                AsyncImage(
                    url: URL(
                        string: currentStoryItem?.user.profilePhotoUrl ?? ""
                    )
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                // Username and time
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        currentStoryItem?.user.username ?? currentStoryItem?
                            .user.displayName ?? "User"
                    )
                    .font(.creatoDisplaySubheadline(.medium))
                    .foregroundColor(.white)

                    Text(storyTimeString)
                        .font(.creatoDisplayCaption())
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()
            }
        }
    }

    // MARK: - Story Bottom Content

    @ViewBuilder
    private func storyBottomContent(story: StoryItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Story caption
            if let caption = story.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.creatoDisplayBody())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .hLeading()
            }

            // Engagement buttons
            //            HStack(spacing: 24) {
            //                // Like button
            //                Button {
            //                    // TODO: Implement like functionality
            //                } label: {
            //                    HStack(spacing: 4) {
            //                        Image(systemName: "heart")
            //                            .font(.title3)
            //                        Text("\(story.post.likeCount)")
            //                            .font(.creatoDisplaySubheadline(.medium))
            //                    }
            //                    .foregroundColor(.white)
            //                }
            //
            //                // Comment button
            //                Button {
            //                    // TODO: Implement comment functionality
            //                } label: {
            //                    HStack(spacing: 4) {
            //                        Image(systemName: "bubble.left")
            //                            .font(.title3)
            //                        Text("\(story.post.commentCount)")
            //                            .font(.creatoDisplaySubheadline(.medium))
            //                    }
            //                    .foregroundColor(.white)
            //                }
            //
            //                Spacer()
            //
            //                // Share button
            //                Button {
            //                    // TODO: Implement share functionality
            //                } label: {
            //                    Image(systemName: "paperplane")
            //                        .font(.title3)
            //                        .foregroundColor(.white)
            //                }
            //            }
        }
    }

    // MARK: - Gesture Overlay

    @ViewBuilder
    private func storyGestureOverlay(geometry: GeometryProxy) -> some View {
        HStack {
            // Left side - previous story
            Button {
                goToPreviousStory()
            } label: {
                Color.clear
                    .frame(width: geometry.size.width * 0.3)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Right side - next story
            Button {
                goToNextStory()
            } label: {
                Color.clear
                    .frame(width: geometry.size.width * 0.3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if abs(value.translation.width) > 50 {
                        if value.translation.width > 0 {
                            goToPreviousStory()
                        } else {
                            goToNextStory()
                        }
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    pauseProgress()
                }
                .onEnded { _ in
                    resumeProgress()
                }
        )
    }

    // MARK: - Progress Management

    private func startStoryProgress() {
        stopTimer()
        startTime = Date()
        isPaused = false

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            _ in
            if !isPaused, let startTime = startTime {
                let elapsed = Date().timeIntervalSince(startTime) - pausedTime
                progress = min(CGFloat(elapsed / storyDuration), 1.0)

                if progress >= 1.0 {
                    goToNextStory()
                }
            }
        }
    }

    private func pauseProgress() {
        isPaused = true
    }

    private func resumeProgress() {
        isPaused = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetAndStartProgress() {
        progress = 0
        pausedTime = 0
        startStoryProgress()
    }

    // MARK: - Navigation

    private func goToNextStory() {
        if currentIndex < storyItems.count - 1 {
            currentIndex += 1
        } else {
            if let onClose {
                onClose()
            } else {
                dismiss()
            }
        }
    }

    private func goToPreviousStory() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    // MARK: - Helpers

    private var storyTimeString: String {
        guard let story = currentStoryItem?.story else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(
            for: story.createdAt,
            relativeTo: Date()
        )
    }

    private func markCurrentStoryAsViewed() {
        guard let storyItem = currentStoryItem,
            let currentUserId = Auth.auth().currentUser?.uid
        else { return }

        Task {
            do {
                let storyService = StoryServiceContainer.shared.storyService
                try await storyService.markStoryAsViewed(
                    storyId: storyItem.story.id!,
                    userId: currentUserId
                )
            } catch {
                print("Failed to mark story as viewed: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StoryViewerView(storyItems: [StoryItem.sampleStory, StoryItem.sampleStory2], onClose: nil)
}
