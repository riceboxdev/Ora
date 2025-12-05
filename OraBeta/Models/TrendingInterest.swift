//
//  TrendingInterest.swift
//  OraBeta
//
//  Model for trending interests with growth metrics
//  Wraps Interest model with trending/featured metadata
//

import Foundation

struct TrendingInterest: Identifiable, Hashable, Equatable {
    let interest: Interest
    let trendScore: Double
    let growthRate: Double
    let timeWindow: TimeWindow
    
    // MARK: - Computed Properties
    
    var id: String { interest.id }
    var name: String { interest.displayName }
    var description: String? { interest.description }
    var coverImageUrl: String? { interest.coverImageUrl }
    var postCount: Int { interest.postCount }
    var followerCount: Int { interest.followerCount }
    var weeklyGrowth: Double { interest.weeklyGrowth }
    var monthlyGrowth: Double { interest.monthlyGrowth }
    var keywords: [String] { interest.keywords }
    
    // MARK: - Time Window
    
    enum TimeWindow: String, CaseIterable {
        case hours24 = "24h"
        case days7 = "7d"
        case days30 = "30d"
        
        var displayName: String {
            switch self {
            case .hours24: return "24 Hours"
            case .days7: return "7 Days"
            case .days30: return "30 Days"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        interest: Interest,
        timeWindow: TimeWindow = .days7
    ) {
        self.interest = interest
        self.timeWindow = timeWindow
        
        // Calculate trend score based on time window
        switch timeWindow {
        case .hours24:
            // For 24h, weight recent activity heavily
            self.growthRate = interest.weeklyGrowth
            self.trendScore = Self.calculateTrendScore(
                postCount: interest.postCount,
                followerCount: interest.followerCount,
                growthRate: interest.weeklyGrowth,
                recencyWeight: 0.7
            )
        case .days7:
            // For 7d, balanced approach
            self.growthRate = interest.weeklyGrowth
            self.trendScore = Self.calculateTrendScore(
                postCount: interest.postCount,
                followerCount: interest.followerCount,
                growthRate: interest.weeklyGrowth,
                recencyWeight: 0.5
            )
        case .days30:
            // For 30d, weight overall engagement
            self.growthRate = interest.monthlyGrowth
            self.trendScore = Self.calculateTrendScore(
                postCount: interest.postCount,
                followerCount: interest.followerCount,
                growthRate: interest.monthlyGrowth,
                recencyWeight: 0.3
            )
        }
    }
    
    // MARK: - Trend Score Calculation
    
    /// Calculate trend score using weighted formula
    /// Score = (postCount * 0.4) + (followerCount * 0.3) + (growthRate * 100 * recencyWeight)
    private static func calculateTrendScore(
        postCount: Int,
        followerCount: Int,
        growthRate: Double,
        recencyWeight: Double
    ) -> Double {
        let postScore = Double(postCount) * 0.4
        let followerScore = Double(followerCount) * 0.3
        let growthScore = growthRate * 100 * recencyWeight
        
        return postScore + followerScore + growthScore
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timeWindow)
    }
    
    static func == (lhs: TrendingInterest, rhs: TrendingInterest) -> Bool {
        lhs.id == rhs.id && lhs.timeWindow == rhs.timeWindow
    }
}
