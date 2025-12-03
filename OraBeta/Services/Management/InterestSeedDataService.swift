//
//  InterestSeedDataService.swift
//  OraBeta
//
//  Service to seed initial interest taxonomy data into Firestore
//

import Foundation
import FirebaseFirestore

@MainActor
class InterestSeedDataService {
    private let db = Firestore.firestore()
    private let interestService: InterestTaxonomyService
    
    init(interestService: InterestTaxonomyService = .shared) {
        self.interestService = interestService
    }
    
    /// Seed all base interests into Firestore
    func seedAllInterests() async throws {
        let baseInterests = buildBaseInterestHierarchy()
        
        for interest in baseInterests {
            try await interestService.createInterest(
                name: interest.name,
                displayName: interest.displayName,
                parentId: interest.parentId,
                description: interest.description,
                keywords: interest.keywords,
                synonyms: interest.synonyms
            )
        }
    }
    
    /// Build the base interest hierarchy
    private func buildBaseInterestHierarchy() -> [InterestSeed] {
        return [
            // Fashion & Style
            InterestSeed(
                name: "fashion",
                displayName: "Fashion",
                parentId: nil,
                description: "Fashion, clothing, and style inspiration",
                keywords: ["fashion", "style", "clothing", "outfit", "apparel"],
                synonyms: ["clothes", "dress", "wardrobe"]
            ),
            InterestSeed(
                name: "womens-fashion",
                displayName: "Women's Fashion",
                parentId: "fashion",
                description: "Women's clothing and style",
                keywords: ["womens", "women", "female", "girl"],
                synonyms: ["ladies fashion", "women wear"]
            ),
            InterestSeed(
                name: "mens-fashion",
                displayName: "Men's Fashion",
                parentId: "fashion",
                description: "Men's clothing and style",
                keywords: ["mens", "men", "male", "guy"],
                synonyms: ["men wear", "gentleman"]
            ),
            InterestSeed(
                name: "accessories",
                displayName: "Accessories",
                parentId: "fashion",
                description: "Fashion accessories, bags, and jewelry",
                keywords: ["accessories", "bag", "jewelry", "watch", "shoes"],
                synonyms: ["add-ons", "adornments"]
            ),
            
            // Beauty & Makeup
            InterestSeed(
                name: "beauty",
                displayName: "Beauty",
                parentId: nil,
                description: "Beauty, makeup, skincare, and cosmetics",
                keywords: ["beauty", "makeup", "cosmetics", "skincare", "skincare"],
                synonyms: ["cosmetics", "makeup"]
            ),
            InterestSeed(
                name: "makeup",
                displayName: "Makeup",
                parentId: "beauty",
                description: "Makeup looks, tutorials, and techniques",
                keywords: ["makeup", "eyeshadow", "lipstick", "foundation"],
                synonyms: ["cosmetics", "face makeup"]
            ),
            InterestSeed(
                name: "skincare",
                displayName: "Skincare",
                parentId: "beauty",
                description: "Skincare routines and products",
                keywords: ["skincare", "skin", "facial", "moisturizer", "cleanser"],
                synonyms: ["face care", "skin routine"]
            ),
            
            // Food & Beverage
            InterestSeed(
                name: "food",
                displayName: "Food",
                parentId: nil,
                description: "Food, recipes, cooking, and culinary inspiration",
                keywords: ["food", "recipe", "cooking", "cuisine", "dish"],
                synonyms: ["cuisine", "culinary", "gastronomy"]
            ),
            InterestSeed(
                name: "desserts",
                displayName: "Desserts",
                parentId: "food",
                description: "Desserts, baking, and sweet treats",
                keywords: ["dessert", "cake", "cookie", "baking", "sweet"],
                synonyms: ["sweets", "pastry", "baked goods"]
            ),
            InterestSeed(
                name: "healthy-eating",
                displayName: "Healthy Eating",
                parentId: "food",
                description: "Healthy recipes and nutrition",
                keywords: ["healthy", "nutrition", "diet", "vegan", "organic"],
                synonyms: ["wellness food", "clean eating"]
            ),
            
            // Fitness & Wellness
            InterestSeed(
                name: "fitness",
                displayName: "Fitness",
                parentId: nil,
                description: "Fitness, exercise, and wellness",
                keywords: ["fitness", "exercise", "workout", "gym", "training"],
                synonyms: ["health", "workout", "physical activity"]
            ),
            InterestSeed(
                name: "yoga",
                displayName: "Yoga",
                parentId: "fitness",
                description: "Yoga and mindfulness",
                keywords: ["yoga", "meditation", "mindfulness", "stretching"],
                synonyms: ["meditation", "pilates"]
            ),
            
            // Home & Decor
            InterestSeed(
                name: "home-decor",
                displayName: "Home & Decor",
                parentId: nil,
                description: "Home decoration and interior design",
                keywords: ["home", "decor", "design", "interior", "furniture"],
                synonyms: ["interior design", "home design"]
            ),
            InterestSeed(
                name: "diy",
                displayName: "DIY",
                parentId: "home-decor",
                description: "DIY projects and crafts",
                keywords: ["diy", "craft", "project", "tutorial", "handmade"],
                synonyms: ["crafts", "handmade"]
            ),
            
            // Travel & Adventures
            InterestSeed(
                name: "travel",
                displayName: "Travel",
                parentId: nil,
                description: "Travel, destinations, and adventure",
                keywords: ["travel", "destination", "vacation", "adventure", "explore"],
                synonyms: ["tourism", "wanderlust"]
            ),
            InterestSeed(
                name: "beaches",
                displayName: "Beaches",
                parentId: "travel",
                description: "Beach destinations and coastal trips",
                keywords: ["beach", "ocean", "coastal", "sand", "sea"],
                synonyms: ["seaside", "coastline"]
            ),
            
            // Photography & Art
            InterestSeed(
                name: "photography",
                displayName: "Photography",
                parentId: nil,
                description: "Photography, visual arts, and creative content",
                keywords: ["photography", "photo", "camera", "visual", "art"],
                synonyms: ["visual arts", "photos"]
            ),
            InterestSeed(
                name: "landscape",
                displayName: "Landscape Photography",
                parentId: "photography",
                description: "Landscape and nature photography",
                keywords: ["landscape", "nature", "scenic", "mountain", "forest"],
                synonyms: ["nature photography", "outdoor photography"]
            ),
            
            // Entertainment
            InterestSeed(
                name: "entertainment",
                displayName: "Entertainment",
                parentId: nil,
                description: "Movies, TV shows, and entertainment",
                keywords: ["entertainment", "movie", "tv", "show", "film"],
                synonyms: ["movies", "television"]
            ),
            InterestSeed(
                name: "music",
                displayName: "Music",
                parentId: "entertainment",
                description: "Music and musicians",
                keywords: ["music", "song", "artist", "musician", "concert"],
                synonyms: ["songs", "musicians"]
            ),
            
            // Technology
            InterestSeed(
                name: "technology",
                displayName: "Technology",
                parentId: nil,
                description: "Technology, gadgets, and innovation",
                keywords: ["technology", "tech", "gadget", "innovation", "digital"],
                synonyms: ["gadgets", "tech news"]
            ),
            
            // Pets & Animals
            InterestSeed(
                name: "pets",
                displayName: "Pets & Animals",
                parentId: nil,
                description: "Pets, animals, and wildlife",
                keywords: ["pet", "dog", "cat", "animal", "wildlife"],
                synonyms: ["animals", "animal lovers"]
            ),
        ]
    }
}

struct InterestSeed {
    let name: String
    let displayName: String
    let parentId: String?
    let description: String?
    let keywords: [String]
    let synonyms: [String]
}
