//
//  StoriesRowView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import FirebaseAuth
import SwiftUI

struct StoriesRowView: View {
    @StateObject private var viewModel: StoriesRowViewModel
    /// Optional namespace used for matched geometry when presenting an overlay
    private let namespace: Namespace.ID?
    /// Optional callback when a story is selected
    private let onStorySelected: ((StoryItem, [StoryItem]) -> Void)?
    @State private var hasLoadedStories = false

    init(
        namespace: Namespace.ID? = nil,
        onStorySelected: ((StoryItem, [StoryItem]) -> Void)? = nil
    ) {
        self.namespace = namespace
        self.onStorySelected = onStorySelected
        _viewModel = StateObject(wrappedValue: StoriesRowViewModel())
    }

    var body: some View {

        // Stories content
        storiesContent
            .task {
                // Prevent reloading every time the row comes back on screen
                guard !hasLoadedStories else { return }
                hasLoadedStories = true
                await viewModel.loadStories()
            }
    }

    @ViewBuilder
    private var storiesContent: some View {
        if viewModel.isLoading {
            loadingStories
        } else if viewModel.storyItems.isEmpty
            && viewModel.currentUserStoryItems == nil
        {
            emptyStories
        } else {
            storiesList
        }
    }

    private var loadingStories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Current user skeleton
                currentUserStorySkeleton

                // Following stories skeletons
                ForEach(0..<5, id: \.self) { _ in
                    storySkeleton
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 110)
    }

    private var emptyStories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Current user add story
                addStoryButton

                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "person.3.sequence")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("No stories yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70)
                .padding(.horizontal)
            }
            .padding(.horizontal)
        }
        .frame(height: 110)
    }

    private var storiesList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Current user story
                if let currentUserStory = viewModel.currentUserStory {
                    currentUserStoryView(story: currentUserStory)
                } else {
                    addStoryButton
                }

                // Following stories
                ForEach(viewModel.storyItems) { story in
                    storyButton(story: story)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 110)
        .onAppear {
            print(
                "🔍 StoriesRowView appeared - User stories: \(viewModel.currentUserStoryItems?.count ?? 0)"
            )
        }
    }

    private var currentUserStorySkeleton: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 62, height: 62)
            }

            Text("You")
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }

    private var storySkeleton: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 62, height: 62)
            }

            Text("...")
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }

    private var addStoryButton: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    )
            }
            .onTapGesture {
                // This would open camera/gallery to create a new story
                // For now, we'll show a placeholder
            }

            Text("Your Story")
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }

    private func currentUserStoryView(story: StoryItem) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 70, height: 70)
                
                AsyncImage(url: URL(string: story.user.profilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(story.user.username.prefix(2)).uppercased())
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
            }
            .modifier(OptionalMatchedGeometry(id: story.id, namespace: namespace))
            
            Text("Your Story")
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .onTapGesture {
            let items = viewModel.currentUserStoryItems ?? [story]
            onStorySelected?(story, items)
        }
    }

    private func storyButton(story: StoryItem) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: story.isViewed 
                                ? [Color.gray.opacity(0.3), Color.gray.opacity(0.3)]
                                : [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: story.isViewed ? 2.0 : 2.5
                    )
                    .frame(width: 70, height: 70)
                
                AsyncImage(url: URL(string: story.user.profilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(story.user.username.prefix(2)).uppercased())
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
            }
            .modifier(OptionalMatchedGeometry(id: story.id, namespace: namespace))
            
            Text(story.user.username)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .onTapGesture {
            onStorySelected?(story, [story])
        }
    }

    private func refreshStories() {
        Task {
            await viewModel.loadStories()
        }
    }
}

// MARK: - Helpers

/// Conditionally applies a matchedGeometryEffect only when a namespace is provided.
private struct OptionalMatchedGeometry: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}

#Preview {
    StoriesRowView()
        .environmentObject(DIContainer.shared)
        .previewAuthenticated()
}
