#!/bin/bash

# Script to restore all environment variables to Vercel
# Run this script and follow the prompts

echo "=========================================="
echo "Restore Environment Variables to Vercel"
echo "=========================================="
echo ""
echo "This script will help you add all required environment variables."
echo "You'll be prompted to enter each value."
echo ""
read -p "Press Enter to continue..."

# Backend variables
echo ""
echo "=== Backend Variables ==="
echo ""

echo "1. MONGODB_URI"
echo "   Enter your MongoDB connection string (can use placeholder database name like 'shared-cluster'):"
vercel env add MONGODB_URI production

echo ""
echo "2. MONGODB_DB_NAME"
echo "   Enter database name for this project (e.g., ios-app-dashboard):"
vercel env add MONGODB_DB_NAME production

echo ""
echo "3. JWT_SECRET"
echo "   Enter your JWT secret (or generate with: openssl rand -hex 32):"
vercel env add JWT_SECRET production

echo ""
echo "4. FIREBASE_PROJECT_ID"
echo "   Enter: angles-423a4"
vercel env add FIREBASE_PROJECT_ID production

echo ""
echo "5. FIREBASE_PRIVATE_KEY"
echo "   Get from Firebase Console → Project Settings → Service Accounts"
echo "   Paste the private key (single line with \\n for newlines):"
vercel env add FIREBASE_PRIVATE_KEY production

echo ""
echo "6. FIREBASE_CLIENT_EMAIL"
echo "   Get from Firebase Console → Project Settings → Service Accounts"
echo "   Paste the client email:"
vercel env add FIREBASE_CLIENT_EMAIL production

echo ""
echo "7. DASHBOARD_URL"
echo "   Enter: https://dashboard.ora.riceboxai.com"
vercel env add DASHBOARD_URL production

# Frontend variables
echo ""
echo "=== Frontend Variables (VITE_*) ==="
echo ""

echo "8. VITE_FIREBASE_API_KEY"
echo "   Enter your Firebase API key:"
vercel env add VITE_FIREBASE_API_KEY production

echo ""
echo "9. VITE_FIREBASE_AUTH_DOMAIN"
echo "   Enter: angles-423a4.firebaseapp.com"
vercel env add VITE_FIREBASE_AUTH_DOMAIN production

echo ""
echo "10. VITE_FIREBASE_PROJECT_ID"
echo "   Enter: angles-423a4"
vercel env add VITE_FIREBASE_PROJECT_ID production

echo ""
echo "11. VITE_FIREBASE_STORAGE_BUCKET"
echo "    Enter: angles-423a4.firebasestorage.app"
vercel env add VITE_FIREBASE_STORAGE_BUCKET production

echo ""
echo "12. VITE_FIREBASE_MESSAGING_SENDER_ID"
echo "    Enter: 1024758653829"
vercel env add VITE_FIREBASE_MESSAGING_SENDER_ID production

echo ""
echo "13. VITE_FIREBASE_APP_ID"
echo "    Enter your Firebase App ID:"
vercel env add VITE_FIREBASE_APP_ID production

echo ""
echo "14. VITE_API_URL"
echo "    Press Enter to leave empty (uses same domain):"
vercel env add VITE_API_URL production

echo ""
echo "=========================================="
echo "All variables added!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify variables: vercel env ls"
echo "2. Redeploy: vercel --prod"
echo ""
