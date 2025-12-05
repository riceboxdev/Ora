//
//  InterestAutocompleteView.swift
//  OraBeta
//
//  Created for interest-based post tagging
//

import SwiftUI

struct InterestAutocompleteView: View {
    @Binding var selectedInterests: Set<String>
    let minInterests: Int
    let maxInterests: Int
    var isFocused: Binding<Bool>? = nil
    
    @State private var query: String = ""
    @State private var suggestions: [InterestSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showSuggestions = false
    @State private var validationError: String?
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let interestService = InterestTaxonomyService.shared
    private let debounceDelay: TimeInterval = 0.3
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected interests display
            if !selectedInterests.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedInterests), id: \.self) { interestId in
                            if let suggestion = suggestions.first(where: { $0.id == interestId }) {
                                InterestChip(interest: suggestion, isSelected: true) {
                                    selectedInterests.remove(interestId)
                                    validateInterests()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Interest input field
            HStack {
                TextField("Search interests...", text: $query)
                    .frame(height: 45)
                    .padding(.horizontal)
                    .background(.quaternary, in: .capsule)
                    .focused($isTextFieldFocused)
                    .onChange(of: query) { oldValue, newValue in
                        debounceSearch(query: newValue)
                    }
                    .onSubmit {
                        // For interests, we don't allow free-form entry
                        // User must select from suggestions
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
                // Interest count indicator
                Text("\(selectedInterests.count)/\(maxInterests) interests")
                    .font(.caption)
                    .foregroundColor(selectedInterests.count >= minInterests ? .secondary : .orange)
            }
            
            // Suggestions list - show when focused and typing
            if (isTextFieldFocused || showSuggestions) && !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            InterestSuggestionRow(suggestion: suggestion) {
                                addInterest(suggestion.id)
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
            validateInterests()
            loadInitialSuggestions()
        }
        .onChange(of: selectedInterests) { oldValue, newValue in
            validateInterests()
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
        guard selectedInterests.count < maxInterests else {
            suggestions = []
            showSuggestions = false
            return
        }
        
        isLoadingSuggestions = true
        showSuggestions = true
        
        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let interests: [Interest]
            if trimmedQuery.isEmpty {
                // Show top-level interests by default
                interests = try await interestService.getTopLevelInterests()
            } else {
                // Search interests
                interests = try await interestService.searchInterests(query: trimmedQuery, limit: 20)
            }
            
            // Convert to suggestions and filter out already selected
            let allSuggestions = interests.map { interest in
                InterestSuggestion(
                    id: interest.id,
                    name: interest.name,
                    displayName: interest.displayName,
                    level: interest.level,
                    path: interest.path
                )
            }
            
            let filtered = allSuggestions.filter { !selectedInterests.contains($0.id) }
            
            await MainActor.run {
                suggestions = filtered
                isLoadingSuggestions = false
            }
        } catch {
            print("⚠️ InterestAutocompleteView: Failed to load suggestions: \(error.localizedDescription)")
            await MainActor.run {
                suggestions = []
                isLoadingSuggestions = false
            }
        }
    }
    
    private func addInterest(_ interestId: String) {
        guard selectedInterests.count < maxInterests else {
            validationError = "Maximum \(maxInterests) interests allowed"
            return
        }
        
        selectedInterests.insert(interestId)
        query = ""
        validateInterests()
        
        // Reload suggestions after adding interest
        Task {
            await loadSuggestions(query: "")
        }
    }
    
    private func validateInterests() {
        let count = selectedInterests.count
        
        if count < minInterests {
            validationError = "At least \(minInterests) interest required"
        } else if count > maxInterests {
            validationError = "Maximum \(maxInterests) interests allowed"
        } else {
            validationError = nil
        }
    }
}

struct InterestSuggestion: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let level: Int
    let path: [String]
}

struct InterestChip: View {
    let interest: InterestSuggestion
    let isSelected: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(interest.displayName)
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

struct InterestSuggestionRow: View {
    let suggestion: InterestSuggestion
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.displayName)
                        .font(.creatoDisplayBody())
                        .foregroundColor(.primary)
                    
                    // Show hierarchy path if not root
                    if !suggestion.path.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.caption2)
                            Text(suggestion.path.joined(separator: " › "))
                                .font(.creatoDisplayCaption2())
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color(.systemGray6), in: .capsule)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedInterests: Set<String> = []
        @State private var isFocused: Bool = false
        
        var body: some View {
            VStack {
                InterestAutocompleteView(
                    selectedInterests: $selectedInterests,
                    minInterests: 1,
                    maxInterests: 5,
                    isFocused: $isFocused
                )
                .padding()
                
                Spacer()
                
                // Debug info
                VStack(alignment: .leading) {
                    Text("Selected Interests:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedInterests.isEmpty ? "None" : Array(selectedInterests).joined(separator: ", "))
                        .font(.caption)
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
