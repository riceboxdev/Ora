// Interest Taxonomy Seed Data
// This file contains the default interest taxonomy structure

/**
 * Generate top-level interests
 */
const generateTopLevelInterests = () => {
  const now = new Date();
  
  return [
    // 1. Fashion
    {
      id: 'fashion',
      name: 'fashion',
      displayName: 'Fashion',
      level: 0,
      path: ['fashion'],
      description: 'Clothing, style, trends, and fashion inspiration',
      keywords: ['fashion', 'style', 'clothing', 'outfit', 'trends'],
      synonyms: ['mode', 'style', 'clothing']
    },
    
    // 2. Photography
    {
      id: 'photography',
      name: 'photography',
      displayName: 'Photography',
      level: 0,
      path: ['photography'],
      description: 'Photography techniques, inspiration, and visual art',
      keywords: ['photography', 'photo', 'camera', 'portrait', 'landscape'],
      synonyms: ['photos', 'pictures', 'images']
    },
    
    // 3. Design
    {
      id: 'design',
      name: 'design',
      displayName: 'Design',
      level: 0,
      path: ['design'],
      description: 'Graphic design, interior design, and product design',
      keywords: ['design', 'graphic', 'interior', 'product', 'creative'],
      synonyms: ['graphics', 'layout', 'aesthetics']
    },
    
    // 4. Art
    {
      id: 'art',
      name: 'art',
      displayName: 'Art',
      level: 0,
      path: ['art'],
      description: 'Traditional art, digital art, street art, and artistic expression',
      keywords: ['art', 'painting', 'drawing', 'illustration', 'artwork'],
      synonyms: ['artwork', 'artistic', 'fine art']
    },
    
    // 5. Beauty
    {
      id: 'beauty',
      name: 'beauty',
      displayName: 'Beauty',
      level: 0,
      path: ['beauty'],
      description: 'Makeup, skincare, hair, and beauty tips',
      keywords: ['beauty', 'makeup', 'skincare', 'hair', 'cosmetics'],
      synonyms: ['cosmetics', 'beauty tips', 'grooming']
    },
    
    // 6. Travel
    {
      id: 'travel',
      name: 'travel',
      displayName: 'Travel',
      level: 0,
      path: ['travel'],
      description: 'Travel destinations, tips, and wanderlust inspiration',
      keywords: ['travel', 'destination', 'vacation', 'wanderlust', 'adventure'],
      synonyms: ['tourism', 'vacation', 'trip']
    },
    
    // 7. Food
    {
      id: 'food',
      name: 'food',
      displayName: 'Food',
      level: 0,
      path: ['food'],
      description: 'Cooking, recipes, restaurants, and culinary inspiration',
      keywords: ['food', 'cooking', 'recipe', 'restaurant', 'culinary'],
      synonyms: ['cuisine', 'cooking', 'recipes']
    },
    
    // 8. Architecture
    {
      id: 'architecture',
      name: 'architecture',
      displayName: 'Architecture',
      level: 0,
      path: ['architecture'],
      description: 'Buildings, structures, and architectural design',
      keywords: ['architecture', 'building', 'structure', 'design', 'urban'],
      synonyms: ['buildings', 'architectural design']
    },
    
    // 9. Lifestyle
    {
      id: 'lifestyle',
      name: 'lifestyle',
      displayName: 'Lifestyle',
      level: 0,
      path: ['lifestyle'],
      description: 'Daily life, wellness, productivity, and personal development',
      keywords: ['lifestyle', 'wellness', 'productivity', 'living', 'habits'],
      synonyms: ['living', 'daily life', 'wellness']
    },
    
    // 10. Creative
    {
      id: 'creative',
      name: 'creative',
      displayName: 'Creative',
      level: 0,
      path: ['creative'],
      description: 'DIY projects, crafts, and creative endeavors',
      keywords: ['creative', 'diy', 'craft', 'handmade', 'project'],
      synonyms: ['diy', 'crafts', 'handmade']
    }
  ];
};

/**
 * Generate fashion sub-interests
 */
const generateFashionSubInterests = () => {
  const now = new Date();
  
  return [
    // Fashion sub-interests (level 1)
    {
      id: 'fashion_models',
      name: 'models',
      displayName: 'Models',
      level: 1,
      path: ['fashion', 'models'],
      parentId: 'fashion',
      description: 'Fashion models, modeling, and model portfolios',
      keywords: ['models', 'modeling', 'fashion model', 'runway model'],
      synonyms: ['modeling', 'fashion models']
    },
    {
      id: 'fashion_streetwear',
      name: 'streetwear',
      displayName: 'Streetwear',
      level: 1,
      path: ['fashion', 'streetwear'],
      parentId: 'fashion',
      description: 'Urban fashion, street style, and casual wear',
      keywords: ['streetwear', 'urban', 'street style', 'casual'],
      synonyms: ['street fashion', 'urban wear']
    },
    {
      id: 'fashion_haute_couture',
      name: 'haute couture',
      displayName: 'Haute Couture',
      level: 1,
      path: ['fashion', 'haute couture'],
      parentId: 'fashion',
      description: 'High fashion, luxury fashion, and designer collections',
      keywords: ['haute couture', 'high fashion', 'luxury', 'designer'],
      synonyms: ['high fashion', 'luxury fashion']
    },
    {
      id: 'fashion_shows',
      name: 'fashion shows',
      displayName: 'Fashion Shows',
      level: 1,
      path: ['fashion', 'fashion shows'],
      parentId: 'fashion',
      description: 'Fashion weeks, runway shows, and fashion events',
      keywords: ['fashion show', 'runway', 'fashion week', 'catwalk'],
      synonyms: ['runway shows', 'fashion week'],
      relatedInterestIds: ['fashion_models']
    }
  ];
};

/**
 * Generate models sub-interests (level 2)
 */
const generateModelsSubInterests = () => {
  return [
    {
      id: 'fashion_models_runway',
      name: 'runway models',
      displayName: 'Runway Models',
      level: 2,
      path: ['fashion', 'models', 'runway models'],
      parentId: 'fashion_models',
      description: 'Professional runway and catwalk models',
      keywords: ['runway', 'catwalk', 'fashion week', 'haute couture'],
      synonyms: ['catwalk models', 'fashion week models'],
      relatedInterestIds: ['fashion_shows']
    }
  ];
};

/**
 * Generate photography sub-interests
 */
const generatePhotographySubInterests = () => {
  return [
    {
      id: 'photography_portrait',
      name: 'portrait photography',
      displayName: 'Portrait Photography',
      level: 1,
      path: ['photography', 'portrait'],
      parentId: 'photography',
      description: 'Portrait photography techniques and inspiration',
      keywords: ['portrait', 'people', 'face', 'headshot', 'model'],
      synonyms: ['portraiture', 'people photography']
    },
    {
      id: 'photography_landscape',
      name: 'landscape photography',
      displayName: 'Landscape Photography',
      level: 1,
      path: ['photography', 'landscape'],
      parentId: 'photography',
      description: 'Landscape and nature photography',
      keywords: ['landscape', 'nature', 'scenery', 'outdoor', 'view'],
      synonyms: ['nature photography', 'scenic photography']
    }
  ];
};

// Export all seed data generation functions
module.exports = {
  generateTopLevelInterests,
  generateFashionSubInterests,
  generateModelsSubInterests,
  generatePhotographySubInterests
};
