//
//  BoomerangGridLinesView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//


import SwiftUI

struct GridLinesView: View {
    @Binding var resolution: CGFloat
    let lineColor: Color
    let lineWidth: CGFloat
    let opacity: Double
    
    init(resolution: Binding<CGFloat>,
         lineColor: Color = .primary,
         lineWidth: CGFloat = 1.0,
         opacity: Double = 1.0) {
        self._resolution = resolution
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let step = min(size.width, size.height) / resolution
                let centerX = size.width / 2
                let centerY = size.height / 2
                
                var path = Path()
                
                // Always draw center lines first
                path.move(to: CGPoint(x: centerX, y: 0))
                path.addLine(to: CGPoint(x: centerX, y: size.height))
                
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: size.width, y: centerY))
                
                // Vertical lines - draw symmetrically from center
                var i = 1
                while true {
                    let offset = CGFloat(i) * step
                    var drewLine = false
                    
                    // Right side
                    let rightX = centerX + offset
                    if rightX <= size.width {
                        path.move(to: CGPoint(x: rightX, y: 0))
                        path.addLine(to: CGPoint(x: rightX, y: size.height))
                        drewLine = true
                    }
                    
                    // Left side
                    let leftX = centerX - offset
                    if leftX >= 0 {
                        path.move(to: CGPoint(x: leftX, y: 0))
                        path.addLine(to: CGPoint(x: leftX, y: size.height))
                        drewLine = true
                    }
                    
                    if !drewLine { break }
                    i += 1
                }
                
                // Horizontal lines - draw symmetrically from center
                i = 1
                while true {
                    let offset = CGFloat(i) * step
                    var drewLine = false
                    
                    // Bottom side
                    let bottomY = centerY + offset
                    if bottomY <= size.height {
                        path.move(to: CGPoint(x: 0, y: bottomY))
                        path.addLine(to: CGPoint(x: size.width, y: bottomY))
                        drewLine = true
                    }
                    
                    // Top side
                    let topY = centerY - offset
                    if topY >= 0 {
                        path.move(to: CGPoint(x: 0, y: topY))
                        path.addLine(to: CGPoint(x: size.width, y: topY))
                        drewLine = true
                    }
                    
                    if !drewLine { break }
                    i += 1
                }
                
                context.stroke(path,
                               with: .color(lineColor),
                               style: StrokeStyle(lineWidth: lineWidth))
            }
            .opacity(opacity)
        }
    }
}
