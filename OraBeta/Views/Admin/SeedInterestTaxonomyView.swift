//
//  SeedInterestTaxonomy.swift
//  OraBeta
//
//  Helper utility to seed the initial interest taxonomy
//  Run this once to populate Firestore with initial interests
//

import Foundation
import SwiftUI

/// View to seed interest taxonomy (for development/admin use)
struct SeedInterestTaxonomyView: View {
    @State private var isSeeding = false
    @State private var message = ""
    @State private var seedCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Interest Taxonomy Seeder")
                .font(.title.bold())
            
            Text("This will populate Firestore with the initial interest taxonomy")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if !message.isEmpty {
                Text(message)
                    .foregroundColor(message.contains("Success") ? .green : .red)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: seedTaxonomy) {
                if isSeeding {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("Seed Interest Taxonomy (\(InterestTaxonomySeed.getAllSeedInterests().count) interests)")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSeeding)
            
            if seedCount > 0 {
                Text("Seeded \(seedCount) interests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func seedTaxonomy() {
        isSeeding = true
        message = "Seeding interests..."
        seedCount = 0
        
        Task {
            do {
                let interests = InterestTaxonomySeed.getAllSeedInterests()
                
                Logger.info("🌱 Starting to seed \(interests.count) interests", service: "SeedTaxonomy")
                
                try await InterestTaxonomyService.shared.batchCreateInterests(interests)
                
                await MainActor.run {
                    seedCount = interests.count
                    message = "✅ Success! Seeded \(interests.count) interests"
                    isSeeding = false
                }
                
                Logger.info("✅ Successfully seeded taxonomy", service: "SeedTaxonomy")
                
            } catch {
                Logger.error("❌ Failed to seed taxonomy: \(error.localizedDescription)", service: "SeedTaxonomy")
                
                await MainActor.run {
                    message = "❌ Error: \(error.localizedDescription)"
                    isSeeding = false
                }
            }
        }
    }
}

#Preview {
    SeedInterestTaxonomyView()
}
