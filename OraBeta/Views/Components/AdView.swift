//
//  AdView.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/21/25.
//

import SwiftUI

struct AdView: View {
    var body: some View {
        VStack {
            HStack {
                Text("Sponsored")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            ZStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(1.0, contentMode: .fit)
                
                VStack {
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.yellow)
                    
                    Text("Ad Space")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                    
                    Text("Your ad could be here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .cornerRadius(12)
            
            Button(action: {
                // Ad action
            }) {
                Text("Learn More")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AdView()
        .padding()
}
