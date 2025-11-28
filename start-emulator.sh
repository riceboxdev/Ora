#!/bin/bash

# Quick start script for Firebase Emulator Suite

echo "🚀 Starting Firebase Emulator Suite..."
echo ""

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo "❌ Error: firebase.json not found. Please run this script from the project root."
    exit 1
fi

# Build functions first
echo "📦 Building Firebase Functions..."
cd functions
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to build functions"
    exit 1
fi

cd ..

# Start emulators
echo ""
echo "🔥 Starting Firebase Emulators..."
echo ""
echo "📍 Emulator UI will be available at: http://localhost:4000"
echo "📍 Functions Emulator: http://localhost:5001"
echo "📍 Auth Emulator: http://localhost:9099"
echo "📍 Firestore Emulator: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop the emulators"
echo ""

firebase emulators:start

