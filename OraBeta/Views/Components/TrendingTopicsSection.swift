//
//  TrendingTopicsSection.swift
//  OraBeta
//
//  Extracted trending topics section for better rendering performance
//

import SwiftUI

struct HomeTrendingTopicsSection: View {
    let trendingTopics: [TrendingTopic]
    let isLoadingTrendingTopics: Bool
    let selectedTrendingTopic: TrendingTopic?
    let onTopicSelected: (TrendingTopic?) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" button
                    Button(action: {
                        Task {
                            await onTopicSelected(nil)
                        }
                    }) {
                        Text("All")
                            .font(.subheadline)
                            .fontWeight(selectedTrendingTopic == nil ? .semibold : .regular)
                            .padding(.horizontal, ViewConstants.Layout.chipHorizontalPadding)
                            .padding(.vertical, ViewConstants.Layout.chipVerticalPadding)
                            .background(
                                selectedTrendingTopic == nil
                                    ? Color.accentColor
                                    : Color.gray.opacity(0.2)
                            )
                            .foregroundColor(
                                selectedTrendingTopic == nil
                                    ? .invertedAccent
                                    : .primary
                            )
                            .cornerRadius(ViewConstants.Layout.chipCornerRadius)
                    }
                    
                    // Loading indicator if loading and no topics yet
                    if isLoadingTrendingTopics && trendingTopics.isEmpty {
                        LoadingIndicator(
                            padding: EdgeInsets(
                                top: ViewConstants.Layout.chipVerticalPadding,
                                leading: ViewConstants.Layout.chipHorizontalPadding,
                                bottom: ViewConstants.Layout.chipVerticalPadding,
                                trailing: ViewConstants.Layout.chipHorizontalPadding
                            )
                        )
                    }
                    
                    // Trending topic chips
                    ForEach(trendingTopics) { topic in
                        TopicChip(
                            topic: topic,
                            isSelected: selectedTrendingTopic?.id == topic.id,
                            onTap: {
                                Task {
                                    await onTopicSelected(topic)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, ViewConstants.Layout.sectionHorizontalPadding)
            }
            .padding(.bottom, ViewConstants.Layout.sectionBottomPadding)
        }
        .background(Color(.systemBackground))
    }
}

/// Individual topic chip button
private struct TopicChip: View {
    let topic: TrendingTopic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(topic.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if topic.growthRate > 0 {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, ViewConstants.Layout.chipHorizontalPadding)
            .padding(.vertical, ViewConstants.Layout.chipVerticalPadding)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color.gray.opacity(0.2)
            )
            .foregroundColor(
                isSelected
                    ? .invertedAccent
                    : .primary
            )
            .cornerRadius(ViewConstants.Layout.chipCornerRadius)
        }
    }
}
