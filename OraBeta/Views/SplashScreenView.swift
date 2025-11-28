//
//  SplashScreenView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var hasAppeared = false
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Background color
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            Color(UIColor.quaternarySystemFill)
                .ignoresSafeArea()
            
            // Logo
            Image("oravectorcropped")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.accent)
                .scaledToFit()
                .frame(width: 150, height: 150)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(isPulsing ? 1.05 : 0.95)
                .onAppear {
                    // Fade in
                    withAnimation(.easeIn(duration: 0.3)) {
                        hasAppeared = true
                    }
                    
                    // Start pulsing loop
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
        }
    }
}

#Preview {
    SplashScreenView()
}
