//
//  ListStyleExtensions.swift
//  OraBeta
//
//  Custom list style extensions for consistent styling across settings views
//

import SwiftUI

/// View modifier that applies the standard settings list style with clear row backgrounds
struct SettingsListStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.visible)
            .background(backgroundColor)
            .listRowBackground(backgroundColor)
            .listSectionSeparator(.hidden)
            .background(backgroundColor)
            .presentationBackground(backgroundColor)
    }
}

extension View {
    /// Applies the standard settings list style with clear row backgrounds
    /// This modifier applies:
    /// - Plain list style
    /// - Hidden scroll content background
    /// - Dynamic background color (black in dark mode, white in light mode)
    /// - Clear row backgrounds
    /// - Hidden section separators
    /// - Presentation background matching the main background
    func settingsListStyle() -> some View {
        modifier(SettingsListStyle())
    }
}

