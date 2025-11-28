//
//  Post+Helpers.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/10/25.
//

import SwiftUI

extension Post {
    /// Get a formatted string of image dimensions
    var dimensionsText: String {
        guard let width = imageWidth, let height = imageHeight else {
            return "Dimensions unknown"
        }
        return "\(width) × \(height)"
    }
    
    /// Get orientation as a readable string
    var orientationText: String {
        if isSquare { return "Square" }
        if isPortrait { return "Portrait" }
        if isLandscape { return "Landscape" }
        return "Unknown"
    }
    
    /// Get an appropriate placeholder height based on image dimensions and width constraint
    /// Useful for creating proper aspect ratio placeholders
    func placeholderHeight(forWidth width: CGFloat) -> CGFloat {
        guard let ratio = aspectRatio else {
            return width // Default to square if no dimensions
        }
        return width / CGFloat(ratio)
    }
}
