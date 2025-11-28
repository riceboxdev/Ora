//
//  TagAutocompleteView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct TagAutocompleteView: View {
    @Binding var selectedTags: Set<String>
    let semanticLabels: [String]?
    let postId: String?
    let minTags: Int
    let maxTags: Int
    var isFocused: Binding<Bool>? = nil
    
    @State private var query: String = ""
    @State private var suggestions: [TagSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showSuggestions = false
    @State private var validationError: String?
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let tagService = TagService.shared
    private let debounceDelay: TimeInterval = 0.3
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected tags display
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                selectedTags.remove(tag)
                                validateTags()
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Tag input field
            HStack {
                TextField("Add Tags...", text: $query)
                    .frame(height: 45)
                    .padding(.horizontal)
                    .background(.quaternary, in: .capsule)
//                TextField("Add tags...", text: $query)
                    .focused($isTextFieldFocused)
//                    .glassEffect(.regular.interactive())
                    .onChange(of: query) { oldValue, newValue in
                        debounceSearch(query: newValue)
                    }
                    .onSubmit {
                        addTagFromQuery()
                    }
                    .onChange(of: isTextFieldFocused) { oldValue, newValue in
                        // Sync with parent focus state if binding is provided
                        isFocused?.wrappedValue = newValue
                        if newValue {
                            showSuggestions = true
                        }
                    }
                
                if isLoadingSuggestions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                // Dismiss keyboard button
                if isTextFieldFocused {
                    Button(action: {
                        isTextFieldFocused = false
                        isFocused?.wrappedValue = false
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Validation error
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                // Tag count indicator
                Text("\(selectedTags.count)/\(maxTags) tags")
                    .font(.caption)
                    .foregroundColor(selectedTags.count >= minTags ? .secondary : .orange)
            }
            
            // Suggestions list - show when focused and typing
            if (isTextFieldFocused || showSuggestions) && !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            TagSuggestionRow(suggestion: suggestion) {
                                addTag(suggestion.tag)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 250)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
        .onAppear {
            validateTags()
            loadInitialSuggestions()
        }
        .onChange(of: selectedTags) { oldValue, newValue in
            validateTags()
        }
    }
    
    private func debounceSearch(query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            if !Task.isCancelled {
                await loadSuggestions(query: query)
            }
        }
    }
    
    private func loadInitialSuggestions() {
        Task {
            await loadSuggestions(query: "")
        }
    }
    
    private func loadSuggestions(query: String) async {
        guard selectedTags.count < maxTags else {
            suggestions = []
            showSuggestions = false
            return
        }
        
        isLoadingSuggestions = true
        showSuggestions = true
        
        do {
            let semanticLabelsArray = semanticLabels ?? []
            let fetchedSuggestions = try await tagService.getTagSuggestions(
                query: query,
                postId: postId,
                semanticLabels: semanticLabelsArray,
                limit: 20
            )
            
            // Filter out already selected tags
            let filtered = fetchedSuggestions.filter { !selectedTags.contains($0.tag) }
            
            await MainActor.run {
                suggestions = filtered
                isLoadingSuggestions = false
            }
        } catch {
            print("⚠️ TagAutocompleteView: Failed to load suggestions: \(error.localizedDescription)")
            await MainActor.run {
                suggestions = []
                isLoadingSuggestions = false
            }
        }
    }
    
    private func addTag(_ tag: String) {
        guard selectedTags.count < maxTags else {
            validationError = "Maximum \(maxTags) tags allowed"
            return
        }
        
        let normalized = tagService.normalizeTag(tag)
        guard !normalized.isEmpty else { return }
        
        selectedTags.insert(normalized)
        query = ""
        // Keep suggestions visible after adding a tag
        // isTextFieldFocused = false
        // isFocused = false
        validateTags()
        
        // Reload suggestions after adding tag
        Task {
            await loadSuggestions(query: "")
        }
    }
    
    private func addTagFromQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        addTag(trimmed)
    }
    
    private func validateTags() {
        let count = selectedTags.count
        
        if count < minTags {
            validationError = "At least \(minTags) tag required"
        } else if count > maxTags {
            validationError = "Maximum \(maxTags) tags allowed"
        } else {
            validationError = nil
        }
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.creatoDisplayCallout())
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive())
        .tint(isSelected ? Color.accent.opacity(0.2) : Color.gray.opacity(0.1))
        .foregroundColor(isSelected ? .accent : .primary)
    }
}

struct TagSuggestionRow: View {
    let suggestion: TagSuggestion
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.displayName)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.primary)
                    
                    // Show source indicator
                    HStack(spacing: 4) {
                        Image(sourceIcon)
                            .font(.caption2)
                        Text(sourceLabel)
                            .font(.creatoDisplayCaption2())
                    }
                    .foregroundColor(sourceColor)
                }
                
                Spacer()
            }
            .padding(.horizontal,20)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color(.systemGray6), in: .capsule)
    }
    
    private var sourceIcon: String {
        switch suggestion.source {
        case .context:
            return "sparkles"
        case .user:
            return "person.icon"
        case .popular:
            return "arrow.trend.up"
        }
    }
    
    private var sourceLabel: String {
        switch suggestion.source {
        case .context:
            return "Context-aware"
        case .user:
            return "Your tags"
        case .popular:
            return "Popular"
        }
    }
    
    private var sourceColor: Color {
        switch suggestion.source {
        case .context:
            return .purple
        case .user:
            return .blue
        case .popular:
            return .red
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTags: Set<String> = ["nature", "photography"]
        @State private var isFocused: Bool = false
        
        var body: some View {
            VStack {
                TagAutocompleteView(
                    selectedTags: $selectedTags,
                    semanticLabels: ["landscape", "outdoor", "scenery"],
                    postId: nil,
                    minTags: 1,
                    maxTags: 10,
                    isFocused: $isFocused
                )
                .padding()
                
                Spacer()
                
                // Debug info
                VStack(alignment: .leading) {
                    Text("Selected Tags:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedTags.isEmpty ? "None" : Array(selectedTags).joined(separator: ", "))
                        .font(.caption)
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
