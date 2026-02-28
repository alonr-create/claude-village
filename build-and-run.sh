#!/bin/bash
# Build and run Claude Village
set -e

cd "$(dirname "$0")"

echo "🦀 Building Claude Village..."
swift build 2>&1

echo "📦 Creating app bundle..."
APP_DIR="ClaudeVillage.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp .build/debug/ClaudeVillage "$APP_DIR/Contents/MacOS/ClaudeVillage"

# Copy ElevenLabs voice files
if [ -d "ClaudeVillage/Resources/voices" ]; then
    echo "🔊 Copying voice files..."
    cp -R ClaudeVillage/Resources/voices "$APP_DIR/Contents/Resources/"
fi

echo "🚀 Launching Claude Village..."
open "$APP_DIR"
