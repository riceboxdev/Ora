//
//  AnimatedMasonryBackground.swift
//  OraBeta
//
//  Created by Nick Rogers on 12/21/25.
//

import SwiftUI

struct AnimatedMasonryBackground: View {
    let images: [WelcomeImage]
    
    // Base animation speed multiplier (1.0 = normal speed, 2.0 = 2x faster, 0.5 = 2x slower)
    // Can be passed as a binding to allow dynamic adjustment
    var speedMultiplier: Double = 1.0
    
    // Animation speeds for each row (different multipliers relative to base speed)
    private let rowSpeeds: [Double] = [1.0, 1.3, 0.8]
    
    // Animation state
    @State private var offsets: [CGFloat] = [0, 0, 0]
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let imageSpacing: CGFloat = 10 // Horizontal spacing between images
            // Account for spacing between rows: 3 rows = 2 gaps
            // Images are 90% of row height, so we need to calculate row height to account for that
            let rowHeight = (screenHeight - (2 * imageSpacing)) / 3
            
            VStack(spacing: imageSpacing) {
                ForEach(0..<3) { rowIndex in
                    AnimatedRow(
                        images: images,
                        rowIndex: rowIndex,
                        height: rowHeight,
                        speed: rowSpeeds[rowIndex] * speedMultiplier,
                        screenWidth: screenWidth,
                        initialOffset: calculateInitialOffset(for: rowIndex, images: images)
                    )
                }
            }
            .frame(width: screenWidth, height: screenHeight)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        // Animation is handled by individual rows
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    // Calculate initial offset for each row to create variety
    private func calculateInitialOffset(for rowIndex: Int, images: [WelcomeImage]) -> CGFloat {
        guard !images.isEmpty else { return 0 }
        let imageWidth: CGFloat = 180
        let imageSpacing: CGFloat = 10
        let singlePassWidth = CGFloat(images.count) * (imageWidth + imageSpacing)
        
        // Each row starts at a different position: 0%, 33%, 66% through the sequence
        let offsetPercentage = Double(rowIndex) / 3.0
        return -singlePassWidth * CGFloat(offsetPercentage)
    }
}

struct AnimatedRow: View {
    let images: [WelcomeImage]
    let rowIndex: Int
    let height: CGFloat
    let speed: Double
    let screenWidth: CGFloat
    let initialOffset: CGFloat
    
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    
    // Calculate single pass width (one complete sequence)
    private var singlePassWidth: CGFloat {
        guard !images.isEmpty else { return screenWidth }
        let imageWidth: CGFloat = 180
        let imageSpacing: CGFloat = 10
        return CGFloat(images.count) * (imageWidth + imageSpacing)
    }
    
    var body: some View {
        if images.isEmpty {
            // Empty state - show subtle gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.1),
                            Color.gray.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: height)
        } else {
            GeometryReader { geometry in
                HStack(spacing: 10) { // Horizontal spacing matches vertical spacing
                    // Render two complete sequences for seamless looping
                    // When first sequence scrolls off screen, second sequence is visible
                    // Then we reset offset to 0 to loop seamlessly
                    ForEach(0..<2) { copyIndex in
                        ForEach(images) { image in
                            AsyncImage(url: URL(string: image.url)) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 180, height: height)
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        )
                                case .success(let loadedImage):
                                    loadedImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 180, height: height)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 180, height: height)
                                @unknown default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 180, height: height)
                                }
                            }
                        }
                    }
                }
                .offset(x: offset)
                .onAppear {
                    // Set initial offset before starting animation
                    offset = initialOffset
                    startScrolling()
                }
                .onDisappear {
                    stopScrolling()
                }
            }
            .frame(height: height)
            .clipped()
        }
    }
    
    private func startScrolling() {
        guard !images.isEmpty else { return }
        
        // Animation speed: pixels per frame (faster = more pixels per frame)
        let pixelsPerFrame: CGFloat = 1.5 * CGFloat(speed)
        let frameInterval: TimeInterval = 0.016 // ~60fps
        
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                // Update offset without animation for smooth continuous scrolling
                self.offset -= pixelsPerFrame
                
                // When we've scrolled one complete sequence, reset to initial offset for seamless loop
                // This maintains the variety between rows
                if self.offset <= -self.singlePassWidth {
                    self.offset = self.initialOffset
                }
            }
        }
        
        // Make sure timer runs on main run loop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopScrolling() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    AnimatedMasonryBackground(images: [])
        .frame(height: 600)
}

