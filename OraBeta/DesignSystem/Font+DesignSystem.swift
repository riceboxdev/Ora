//
//  FontExtension.swift
//  OraBeta
//
//  Custom font utilities for easy font usage throughout the app
//
//  Usage Examples:
//  ----------------
//  // Semantic styles (recommended)
//  Text("Title").font(.creatoDisplayTitle())
//  Text("Body").font(.creatoDisplayBody())
//  Text("Caption").font(.creatoDisplayCaption())
//
//  // Custom weight and size
//  Text("Custom").font(.creatoDisplay(.bold, size: 20))
//  Text("Italic").font(.creatoDisplay(.regular, size: 16, italic: true))
//
//  // HagridTextBold
//  Text("Bold Text").font(.hagridTextBold(size: 18))
//
//  // With different weights
//  Text("Bold Title").font(.creatoDisplayTitle(.bold))
//  Text("Light Body").font(.creatoDisplayBody(.light))
//

import SwiftUI

extension Font {
    // MARK: - CreatoDisplay Font Family
    
    /// CreatoDisplay font with different weights
    enum CreatoDisplayWeight {
        case thin
        case light
        case regular
        case medium
        case bold
        case extraBold
        case black
        
        var fontName: String {
            switch self {
            case .thin: return "CreatoDisplay-Thin"
            case .light: return "CreatoDisplay-Light"
            case .regular: return "CreatoDisplay-Regular"
            case .medium: return "CreatoDisplay-Medium"
            case .bold: return "CreatoDisplay-Bold"
            case .extraBold: return "CreatoDisplay-ExtraBold"
            case .black: return "CreatoDisplay-Black"
            }
        }
        
        var italicFontName: String {
            switch self {
            case .thin: return "CreatoDisplay-Thin"
            case .light: return "CreatoDisplay-LightItalic"
            case .regular: return "CreatoDisplay-RegularItalic"
            case .medium: return "CreatoDisplay-MediumItalic"
            case .bold: return "CreatoDisplay-BoldItalic"
            case .extraBold: return "CreatoDisplay-ExtraBoldItalic"
            case .black: return "CreatoDisplay-BlackItalic"
            }
        }
    }
    
    /// Create a CreatoDisplay font with specified weight and size
    static func creatoDisplay(_ weight: CreatoDisplayWeight = .regular, size: CGFloat, italic: Bool = false) -> Font {
        let fontName = italic ? weight.italicFontName : weight.fontName
        return .custom(fontName, size: size)
    }
    
    // MARK: - HagridText Font Family
    
    /// HagridTextBold font
    static func hagridTextBold(size: CGFloat) -> Font {
        return .custom("HagridTextBold", size: size)
    }
    
    // MARK: - Semantic Font Styles with CreatoDisplay
    
    /// Large title style (34pt) using CreatoDisplay
    static func creatoDisplayLargeTitle(_ weight: CreatoDisplayWeight = .bold) -> Font {
        return creatoDisplay(weight, size: 34)
    }
    
    /// Title style (28pt) using CreatoDisplay
    static func creatoDisplayTitle(_ weight: CreatoDisplayWeight = .bold) -> Font {
        return creatoDisplay(weight, size: 28)
    }
    
    /// Title2 style (22pt) using CreatoDisplay
    static func creatoDisplayTitle2(_ weight: CreatoDisplayWeight = .medium) -> Font {
        return creatoDisplay(weight, size: 22)
    }
    
    /// Title3 style (20pt) using CreatoDisplay
    static func creatoDisplayTitle3(_ weight: CreatoDisplayWeight = .medium) -> Font {
        return creatoDisplay(weight, size: 20)
    }
    
    /// Headline style (17pt, semibold) using CreatoDisplay
    static func creatoDisplayHeadline(_ weight: CreatoDisplayWeight = .bold) -> Font {
        return creatoDisplay(weight, size: 17)
    }
    
    /// Body style (17pt) using CreatoDisplay
    static func creatoDisplayBody(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 17)
    }
    
    /// Callout style (16pt) using CreatoDisplay
    static func creatoDisplayCallout(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 16)
    }
    
    /// Subheadline style (15pt) using CreatoDisplay
    static func creatoDisplaySubheadline(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 15)
    }
    
    /// Footnote style (13pt) using CreatoDisplay
    static func creatoDisplayFootnote(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 13)
    }
    
    /// Caption style (12pt) using CreatoDisplay
    static func creatoDisplayCaption(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 12)
    }
    
    /// Caption2 style (11pt) using CreatoDisplay
    static func creatoDisplayCaption2(_ weight: CreatoDisplayWeight = .regular) -> Font {
        return creatoDisplay(weight, size: 11)
    }
}

// MARK: - Navigation Title Font Modifier

extension View {
    /// Applies Creato Display font to navigation titles
    /// This uses UIKit appearance API to customize the navigation bar title font
    /// - Parameters:
    ///   - weight: The weight of the Creato Display font (default: .bold)
    ///   - size: The font size for inline titles (default: 17pt)
    ///   - largeTitleSize: The font size for large titles (default: 34pt)
    func navigationTitleFont(
        weight: Font.CreatoDisplayWeight = .bold,
        size: CGFloat = 17,
        largeTitleSize: CGFloat = 34
    ) -> some View {
        self.onAppear {
            configureNavigationBarAppearance(
                weight: weight,
                size: size,
                largeTitleSize: largeTitleSize
            )
        }
    }
    
    /// Configures the navigation bar appearance with Creato Display font
    private func configureNavigationBarAppearance(
        weight: Font.CreatoDisplayWeight,
        size: CGFloat,
        largeTitleSize: CGFloat
    ) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Create UIFont for inline titles
        if let titleFont = UIFont(name: weight.fontName, size: size) {
            appearance.titleTextAttributes = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
        }
        
        // Create UIFont for large titles
        if let largeTitleFont = UIFont(name: weight.fontName, size: largeTitleSize) {
            appearance.largeTitleTextAttributes = [
                .font: largeTitleFont,
                .foregroundColor: UIColor.label
            ]
        }
        
        // Don't configure button appearance - let it use default tint color (AccentColor from assets)
        // This ensures navigation bar buttons use the accent color
        
        // Apply to all navigation bar appearances
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Explicitly set tint color from AccentColor asset
        // Try to get the AccentColor from assets, fallback to system accent if not found
        if let accentColor = UIColor(named: "AccentColor") {
            UINavigationBar.appearance().tintColor = accentColor
        } else {
            // Fallback to system accent color
            UINavigationBar.appearance().tintColor = UIColor.systemBlue
        }
    }
}

