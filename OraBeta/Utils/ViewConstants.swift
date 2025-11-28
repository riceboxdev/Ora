//
//  ViewConstants.swift
//  OraBeta
//
//  UI/UX constants for consistent design across views
//

import SwiftUI

enum ViewConstants {
    // MARK: - Toolbar
    enum Toolbar {
        static let logoHeight: CGFloat = 40
        static let buttonSize: CGFloat = 35
    }
    
    // MARK: - Layout
    enum Layout {
        static let defaultSpacing: CGFloat = 10
        static let cornerRadius: CGFloat = 20
        static let chipCornerRadius: CGFloat = 20
        static let chipHorizontalPadding: CGFloat = 16
        static let chipVerticalPadding: CGFloat = 8
        static let sectionHorizontalPadding: CGFloat = 16
        static let sectionBottomPadding: CGFloat = 12
    }
    
    // MARK: - Animation
    enum Animation {
        static let smooth: SwiftUI.Animation = .smooth
    }
}
