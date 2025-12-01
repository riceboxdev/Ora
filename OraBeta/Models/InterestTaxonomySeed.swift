//
//  InterestTaxonomySeed.swift
//  OraBeta
//
//  Initial seed data for interest taxonomy
//  Based on Pinterest's top-level interests
//

import Foundation

struct InterestTaxonomySeed {
    
    /// Generate initial top-level interests
    static func generateTopLevelInterests() -> [Interest] {
        let now = Date()
        
        return [
            // 1. Fashion
            Interest(
                id: "fashion",
                name: "fashion",
                displayName: "Fashion",
                level: 0,
                path: ["fashion"],
                description: "Clothing, style, trends, and fashion inspiration",
                createdAt: now,
                updatedAt: now,
                keywords: ["fashion", "style", "clothing", "outfit", "trends"],
                synonyms: ["mode", "style", "clothing"]
            ),
            
            // 2. Photography
            Interest(
                id: "photography",
                name: "photography",
                displayName: "Photography",
                level: 0,
                path: ["photography"],
                description: "Photography techniques, inspiration, and visual art",
                createdAt: now,
                updatedAt: now,
                keywords: ["photography", "photo", "camera", "portrait", "landscape"],
                synonyms: ["photos", "pictures", "images"]
            ),
            
            // 3. Design
            Interest(
                id: "design",
                name: "design",
                displayName: "Design",
                level: 0,
                path: ["design"],
                description: "Graphic design, interior design, and product design",
                createdAt: now,
                updatedAt: now,
                keywords: ["design", "graphic", "interior", "product", "creative"],
                synonyms: ["graphics", "layout", "aesthetics"]
            ),
            
            // 4. Art
            Interest(
                id: "art",
                name: "art",
                displayName: "Art",
                level: 0,
                path: ["art"],
                description: "Traditional art, digital art, street art, and artistic expression",
                createdAt: now,
                updatedAt: now,
                keywords: ["art", "painting", "drawing", "illustration", "artwork"],
                synonyms: ["artwork", "artistic", "fine art"]
            ),
            
            // 5. Beauty
            Interest(
                id: "beauty",
                name: "beauty",
                displayName: "Beauty",
                level: 0,
                path: ["beauty"],
                description: "Makeup, skincare, hair, and beauty tips",
                createdAt: now,
                updatedAt: now,
                keywords: ["beauty", "makeup", "skincare", "hair", "cosmetics"],
                synonyms: ["cosmetics", "beauty tips", "grooming"]
            ),
            
            // 6. Travel
            Interest(
                id: "travel",
                name: "travel",
                displayName: "Travel",
                level: 0,
                path: ["travel"],
                description: "Travel destinations, tips, and wanderlust inspiration",
                createdAt: now,
                updatedAt: now,
                keywords: ["travel", "destination", "vacation", "wanderlust", "adventure"],
                synonyms: ["tourism", "vacation", "trip"]
            ),
            
            // 7. Food
            Interest(
                id: "food",
                name: "food",
                displayName: "Food",
                level: 0,
                path: ["food"],
                description: "Cooking, recipes, restaurants, and culinary inspiration",
                createdAt: now,
                updatedAt: now,
                keywords: ["food", "cooking", "recipe", "restaurant", "culinary"],
                synonyms: ["cuisine", "cooking", "recipes"]
            ),
            
            // 8. Architecture
            Interest(
                id: "architecture",
                name: "architecture",
                displayName: "Architecture",
                level: 0,
                path: ["architecture"],
                description: "Buildings, structures, and architectural design",
                createdAt: now,
                updatedAt: now,
                keywords: ["architecture", "building", "structure", "design", "urban"],
                synonyms: ["buildings", "architectural design"]
            ),
            
            // 9. Lifestyle
            Interest(
                id: "lifestyle",
                name: "lifestyle",
                displayName: "Lifestyle",
                level: 0,
                path: ["lifestyle"],
                description: "Daily life, wellness, productivity, and personal development",
                createdAt: now,
                updatedAt: now,
                keywords: ["lifestyle", "wellness", "productivity", "living", "habits"],
                synonyms: ["living", "daily life", "wellness"]
            ),
            
            // 10. Creative
            Interest(
                id: "creative",
                name: "creative",
                displayName: "Creative",
                level: 0,
                path: ["creative"],
                description: "DIY projects, crafts, and creative endeavors",
                createdAt: now,
                updatedAt: now,
                keywords: ["creative", "diy", "craft", "handmade", "project"],
                synonyms: ["diy", "crafts", "handmade"]
            )
        ]
    }
    
    /// Generate second-level interests for Fashion
    static func generateFashionSubInterests() -> [Interest] {
        let now = Date()
        
        return [
            Interest(
                id: "fashion_models",
                name: "models",
                displayName: "Models",
                parentId: "fashion",
                level: 1,
                path: ["fashion", "models"],
                description: "Fashion models, modeling, and model portfolios",
                createdAt: now,
                updatedAt: now,
                keywords: ["models", "modeling", "fashion model", "runway model"],
                synonyms: ["modeling", "fashion models"]
            ),
            
            Interest(
                id: "fashion_streetwear",
                name: "streetwear",
                displayName: "Streetwear",
                parentId: "fashion",
                level: 1,
                path: ["fashion", "streetwear"],
                description: "Urban fashion, street style, and casual wear",
                createdAt: now,
                updatedAt: now,
                keywords: ["streetwear", "urban", "street style", "casual"],
                synonyms: ["street fashion", "urban wear"]
            ),
            
            Interest(
                id: "fashion_haute_couture",
                name: "haute couture",
                displayName: "Haute Couture",
                parentId: "fashion",
                level: 1,
                path: ["fashion", "haute couture"],
                description: "High fashion, luxury fashion, and designer collections",
                createdAt: now,
                updatedAt: now,
                keywords: ["haute couture", "high fashion", "luxury", "designer"],
                synonyms: ["high fashion", "luxury fashion"]
            ),
            
            Interest(
                id: "fashion_shows",
                name: "fashion shows",
                displayName: "Fashion Shows",
                parentId: "fashion",
                level: 1,
                path: ["fashion", "fashion shows"],
                description: "Fashion weeks, runway shows, and fashion events",
                createdAt: now,
                updatedAt: now,
                relatedInterestIds: ["fashion_models"],
                keywords: ["fashion show", "runway", "fashion week", "catwalk"],
                synonyms: ["runway shows", "fashion week"]
            )
        ]
    }
    
    /// Generate third-level interests for Models
    static func generateModelsSubInterests() -> [Interest] {
        let now = Date()
        
        return [
            Interest(
                id: "fashion_models_runway",
                name: "runway models",
                displayName: "Runway Models",
                parentId: "fashion_models",
                level: 2,
                path: ["fashion", "models", "runway models"],
                description: "Professional runway and catwalk models",
                createdAt: now,
                updatedAt: now,
                relatedInterestIds: ["fashion_shows"],
                keywords: ["runway", "catwalk", "fashion week", "haute couture"],
                synonyms: ["catwalk models", "fashion week models"]
            ),
            
            Interest(
                id: "fashion_models_editorial",
                name: "editorial models",
                displayName: "Editorial Models",
                parentId: "fashion_models",
                level: 2,
                path: ["fashion", "models", "editorial models"],
                description: "Editorial and magazine fashion models",
                createdAt: now,
                updatedAt: now,
                keywords: ["editorial", "magazine", "photoshoot", "fashion photography"],
                synonyms: ["magazine models", "fashion editorial"]
            ),
            
            Interest(
                id: "fashion_models_commercial",
                name: "commercial models",
                displayName: "Commercial Models",
                parentId: "fashion_models",
                level: 2,
                path: ["fashion", "models", "commercial models"],
                description: "Commercial and advertising models",
                createdAt: now,
                updatedAt: now,
                keywords: ["commercial", "advertising", "brand", "campaign"],
                synonyms: ["advertising models", "brand models"]
            ),
            
            Interest(
                id: "fashion_models_diversity",
                name: "diverse models",
                displayName: "Diverse Models",
                parentId: "fashion_models",
                level: 2,
                path: ["fashion", "models", "diverse models"],
                description: "Diverse representation in modeling",
                createdAt: now,
                updatedAt: now,
                keywords: ["diversity", "representation", "inclusive", "body positive"],
                synonyms: ["inclusive modeling", "representation"]
            )
        ]
    }
    
    /// Generate Photography sub-interests
    static func generatePhotographySubInterests() -> [Interest] {
        let now = Date()
        
        return [
            Interest(
                id: "photography_portrait",
                name: "portrait photography",
                displayName: "Portrait Photography",
                parentId: "photography",
                level: 1,
                path: ["photography", "portrait photography"],
                description: "Portrait and people photography",
                createdAt: now,
                updatedAt: now,
                keywords: ["portrait", "people", "headshot", "face"],
                synonyms: ["portraits", "people photography"]
            ),
            
            Interest(
                id: "photography_landscape",
                name: "landscape photography",
                displayName: "Landscape Photography",
                parentId: "photography",
                level: 1,
                path: ["photography", "landscape photography"],
                description: "Nature and landscape photography",
                createdAt: now,
                updatedAt: now,
                keywords: ["landscape", "nature", "scenery", "outdoor"],
                synonyms: ["nature photography", "scenic photography"]
            ),
            
            Interest(
                id: "photography_street",
                name: "street photography",
                displayName: "Street Photography",
                parentId: "photography",
                level: 1,
                path: ["photography", "street photography"],
                description: "Urban and candid street photography",
                createdAt: now,
                updatedAt: now,
                keywords: ["street", "urban", "candid", "city"],
                synonyms: ["urban photography", "candid photography"]
            ),
            
            Interest(
                id: "photography_fashion",
                name: "fashion photography",
                displayName: "Fashion Photography",
                parentId: "photography",
                level: 1,
                path: ["photography", "fashion photography"],
                description: "Fashion and style photography",
                createdAt: now,
                updatedAt: now,
                relatedInterestIds: ["fashion", "fashion_models"],
                keywords: ["fashion", "style", "editorial", "runway"],
                synonyms: ["style photography", "fashion editorial"]
            )
        ]
    }
    
    /// Get all seed interests
    static func getAllSeedInterests() -> [Interest] {
        var all: [Interest] = []
        all.append(contentsOf: generateTopLevelInterests())
        all.append(contentsOf: generateFashionSubInterests())
        all.append(contentsOf: generateModelsSubInterests())
        all.append(contentsOf: generatePhotographySubInterests())
        return all
    }
}
