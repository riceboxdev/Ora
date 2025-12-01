# Admin Dashboard Feature: Seed Interest Taxonomy

## Overview

We need a "One-Click Seed" feature in the admin dashboard to populate the initial Interest Taxonomy. This will create the foundational 18 interests (Fashion, Photography, etc.) that the app relies on.

**Goal:** Allow admins to reset or initialize the taxonomy with a standard set of categories.

---

## 1. UI Requirements

Add a **"Seed Taxonomy"** button to the Interest Taxonomy management page (e.g., in the header or settings menu).

**Interaction:**
1. Admin clicks "Seed Taxonomy"
2. Show confirmation modal:
   > "This will create 18 foundational interests. Existing interests with the same IDs will be skipped. Continue?"
3. On confirmation, execute the batch write operation
4. Show success message: "Successfully seeded 18 interests"

---

## 2. The Seed Data (JSON)

Use this exact data structure. It contains 3 levels of hierarchy.

```json
[
  // LEVEL 0: ROOT INTERESTS
  {
    "id": "fashion",
    "name": "fashion",
    "displayName": "Fashion",
    "level": 0,
    "path": ["fashion"],
    "parentId": null,
    "description": "Clothing, style, trends, and fashion inspiration",
    "keywords": ["fashion", "style", "clothing", "outfit", "trends"],
    "synonyms": ["mode", "style", "clothing"]
  },
  {
    "id": "photography",
    "name": "photography",
    "displayName": "Photography",
    "level": 0,
    "path": ["photography"],
    "parentId": null,
    "description": "Photography techniques, inspiration, and visual art",
    "keywords": ["photography", "photo", "camera", "portrait", "landscape"],
    "synonyms": ["photos", "pictures", "images"]
  },
  {
    "id": "design",
    "name": "design",
    "displayName": "Design",
    "level": 0,
    "path": ["design"],
    "parentId": null,
    "description": "Graphic design, interior design, and product design",
    "keywords": ["design", "graphic", "interior", "product", "creative"],
    "synonyms": ["graphics", "layout", "aesthetics"]
  },
  {
    "id": "art",
    "name": "art",
    "displayName": "Art",
    "level": 0,
    "path": ["art"],
    "parentId": null,
    "description": "Traditional art, digital art, street art, and artistic expression",
    "keywords": ["art", "painting", "drawing", "illustration", "artwork"],
    "synonyms": ["artwork", "artistic", "fine art"]
  },
  {
    "id": "beauty",
    "name": "beauty",
    "displayName": "Beauty",
    "level": 0,
    "path": ["beauty"],
    "parentId": null,
    "description": "Makeup, skincare, hair, and beauty tips",
    "keywords": ["beauty", "makeup", "skincare", "hair", "cosmetics"],
    "synonyms": ["cosmetics", "beauty tips", "grooming"]
  },
  {
    "id": "travel",
    "name": "travel",
    "displayName": "Travel",
    "level": 0,
    "path": ["travel"],
    "parentId": null,
    "description": "Travel destinations, tips, and wanderlust inspiration",
    "keywords": ["travel", "destination", "vacation", "wanderlust", "adventure"],
    "synonyms": ["tourism", "vacation", "trip"]
  },
  {
    "id": "food",
    "name": "food",
    "displayName": "Food",
    "level": 0,
    "path": ["food"],
    "parentId": null,
    "description": "Cooking, recipes, restaurants, and culinary inspiration",
    "keywords": ["food", "cooking", "recipe", "restaurant", "culinary"],
    "synonyms": ["cuisine", "cooking", "recipes"]
  },
  {
    "id": "architecture",
    "name": "architecture",
    "displayName": "Architecture",
    "level": 0,
    "path": ["architecture"],
    "parentId": null,
    "description": "Buildings, structures, and architectural design",
    "keywords": ["architecture", "building", "structure", "design", "urban"],
    "synonyms": ["buildings", "architectural design"]
  },
  {
    "id": "lifestyle",
    "name": "lifestyle",
    "displayName": "Lifestyle",
    "level": 0,
    "path": ["lifestyle"],
    "parentId": null,
    "description": "Daily life, wellness, productivity, and personal development",
    "keywords": ["lifestyle", "wellness", "productivity", "living", "habits"],
    "synonyms": ["living", "daily life", "wellness"]
  },
  {
    "id": "creative",
    "name": "creative",
    "displayName": "Creative",
    "level": 0,
    "path": ["creative"],
    "parentId": null,
    "description": "DIY projects, crafts, and creative endeavors",
    "keywords": ["creative", "diy", "craft", "handmade", "project"],
    "synonyms": ["diy", "crafts", "handmade"]
  },

  // LEVEL 1: FASHION SUB-INTERESTS
  {
    "id": "fashion_models",
    "name": "models",
    "displayName": "Models",
    "level": 1,
    "path": ["fashion", "models"],
    "parentId": "fashion",
    "description": "Fashion models, modeling, and model portfolios",
    "keywords": ["models", "modeling", "fashion model", "runway model"],
    "synonyms": ["modeling", "fashion models"]
  },
  {
    "id": "fashion_streetwear",
    "name": "streetwear",
    "displayName": "Streetwear",
    "level": 1,
    "path": ["fashion", "streetwear"],
    "parentId": "fashion",
    "description": "Urban fashion, street style, and casual wear",
    "keywords": ["streetwear", "urban", "street style", "casual"],
    "synonyms": ["street fashion", "urban wear"]
  },
  {
    "id": "fashion_haute_couture",
    "name": "haute couture",
    "displayName": "Haute Couture",
    "level": 1,
    "path": ["fashion", "haute couture"],
    "parentId": "fashion",
    "description": "High fashion, luxury fashion, and designer collections",
    "keywords": ["haute couture", "high fashion", "luxury", "designer"],
    "synonyms": ["high fashion", "luxury fashion"]
  },
  {
    "id": "fashion_shows",
    "name": "fashion shows",
    "displayName": "Fashion Shows",
    "level": 1,
    "path": ["fashion", "fashion shows"],
    "parentId": "fashion",
    "description": "Fashion weeks, runway shows, and fashion events",
    "keywords": ["fashion show", "runway", "fashion week", "catwalk"],
    "synonyms": ["runway shows", "fashion week"],
    "relatedInterestIds": ["fashion_models"]
  },

  // LEVEL 2: MODELS SUB-INTERESTS
  {
    "id": "fashion_models_runway",
    "name": "runway models",
    "displayName": "Runway Models",
    "level": 2,
    "path": ["fashion", "models", "runway models"],
    "parentId": "fashion_models",
    "description": "Professional runway and catwalk models",
    "keywords": ["runway", "catwalk", "fashion week", "haute couture"],
    "synonyms": ["catwalk models", "fashion week models"],
    "relatedInterestIds": ["fashion_shows"]
  },
  {
    "id": "fashion_models_editorial",
    "name": "editorial models",
    "displayName": "Editorial Models",
    "level": 2,
    "path": ["fashion", "models", "editorial models"],
    "parentId": "fashion_models",
    "description": "Editorial and magazine fashion models",
    "keywords": ["editorial", "magazine", "photoshoot", "fashion photography"],
    "synonyms": ["magazine models", "fashion editorial"]
  },
  {
    "id": "fashion_models_commercial",
    "name": "commercial models",
    "displayName": "Commercial Models",
    "level": 2,
    "path": ["fashion", "models", "commercial models"],
    "parentId": "fashion_models",
    "description": "Commercial and advertising models",
    "keywords": ["commercial", "advertising", "brand", "campaign"],
    "synonyms": ["advertising models", "brand models"]
  },
  {
    "id": "fashion_models_diversity",
    "name": "diverse models",
    "displayName": "Diverse Models",
    "level": 2,
    "path": ["fashion", "models", "diverse models"],
    "parentId": "fashion_models",
    "description": "Diverse representation in modeling",
    "keywords": ["diversity", "representation", "inclusive", "body positive"],
    "synonyms": ["inclusive modeling", "representation"]
  },

  // LEVEL 1: PHOTOGRAPHY SUB-INTERESTS
  {
    "id": "photography_portrait",
    "name": "portrait photography",
    "displayName": "Portrait Photography",
    "level": 1,
    "path": ["photography", "portrait photography"],
    "parentId": "photography",
    "description": "Portrait and people photography",
    "keywords": ["portrait", "people", "headshot", "face"],
    "synonyms": ["portraits", "people photography"]
  },
  {
    "id": "photography_landscape",
    "name": "landscape photography",
    "displayName": "Landscape Photography",
    "level": 1,
    "path": ["photography", "landscape photography"],
    "parentId": "photography",
    "description": "Nature and landscape photography",
    "keywords": ["landscape", "nature", "scenery", "outdoor"],
    "synonyms": ["nature photography", "scenic photography"]
  },
  {
    "id": "photography_street",
    "name": "street photography",
    "displayName": "Street Photography",
    "level": 1,
    "path": ["photography", "street photography"],
    "parentId": "photography",
    "description": "Urban and candid street photography",
    "keywords": ["street", "urban", "candid", "city"],
    "synonyms": ["urban photography", "candid photography"]
  },
  {
    "id": "photography_fashion",
    "name": "fashion photography",
    "displayName": "Fashion Photography",
    "level": 1,
    "path": ["photography", "fashion photography"],
    "parentId": "photography",
    "description": "Fashion and style photography",
    "keywords": ["fashion", "style", "editorial", "runway"],
    "synonyms": ["style photography", "fashion editorial"],
    "relatedInterestIds": ["fashion", "fashion_models"]
  }
]
```

---

## 3. Implementation Code (Firebase Admin SDK)

Use this function to perform the seed operation. It uses a batch write to ensure efficiency.

```typescript
import * as admin from 'firebase-admin';

async function seedTaxonomy(seedData: any[]) {
  const db = admin.firestore();
  const batch = db.batch();
  const collectionRef = db.collection('interests');
  
  console.log(`🌱 Seeding ${seedData.length} interests...`);
  
  for (const interest of seedData) {
    const docRef = collectionRef.doc(interest.id);
    
    // Check if exists first to avoid overwriting existing stats
    // Or use { merge: true } to update metadata while keeping stats
    batch.set({
      ...interest,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Initialize stats if they don't exist, but don't overwrite if they do
      postCount: 0,
      followerCount: 0,
      weeklyGrowth: 0,
      monthlyGrowth: 0,
      relatedInterestIds: interest.relatedInterestIds || []
    }, { merge: true });
  }
  
  await batch.commit();
  console.log('✅ Taxonomy seeded successfully!');
}
```

---

## 4. API Endpoint

Expose this as a POST endpoint:

`POST /api/admin/taxonomy/seed`

**Response:**
```json
{
  "success": true,
  "count": 18,
  "message": "Successfully seeded 18 interests"
}
```
