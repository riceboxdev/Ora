//
//  MaintenanceModeView.swift
//  OraBeta
//
//  View shown when maintenance mode is enabled
//

import SwiftUI

struct MaintenanceModeView: View {
    @ObservedObject private var remoteConfigService = RemoteConfigService.shared
    
    var body: some View {
        ZStack {
            gridLinesBackground()
            
            VStack(spacing: 24) {
                Image("sleep.face")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                Text("Under Maintenance")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("We're currently performing maintenance to improve your experience. Please check back soon.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
//                Button(action: {
//                    // Force refresh Remote Config
//                    remoteConfigService.fetchConfig()
//                }) {
//                    Text("Check Again")
//                        .font(.creatoDisplayBody(.bold))
//                        .foregroundColor(.whiteui)
//                        .padding(.horizontal, 32)
//                        .padding(.vertical, 12)
//                }
//                .buttonStyle(.glassProminent)
//                .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private func gridLinesBackground() -> some View {
        GridLinesView(
            resolution: .constant(10),
            lineColor: .primary,
            lineWidth: 1,
            opacity: 0.1
        )
        .ignoresSafeArea()
//        .mask(
//            LinearGradient(
//                gradient: Gradient(stops: [
//                    .init(color: .white, location: 0.0),
//                    .init(color: .white, location: 0.6),
//                    .init(color: .white.opacity(0.3), location: 0.85),
//                    .init(color: .clear, location: 1.0)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        )
//        .ignoresSafeArea()
    }
}

#Preview {
    MaintenanceModeView()
}

