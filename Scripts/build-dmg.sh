#!/bin/bash

# PasteDeck DMG Build Script
# Builds a signed .app bundle and creates a DMG for distribution
# No Apple Developer Account required (uses ad-hoc signing)

set -e

# Configuration
APP_NAME="PasteDeck"
VERSION="1.0.0"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
RESOURCES_DIR="Resources"
DMG_NAME="$APP_NAME-$VERSION.dmg"

echo "📦 PasteDeck DMG Builder v$VERSION"
echo "=================================="
echo ""

# Step 1: Build app bundle
echo "🔨 Step 1/4: Building app bundle..."
./build.sh

# Step 2: Add icon if available
echo ""
echo "🎨 Step 2/4: Adding resources..."
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    echo "✅ App icon copied"
else
    echo "⚠️  AppIcon.icns not found in $RESOURCES_DIR/"
    echo "   App will use default icon. See Resources/README.md for instructions."
fi

# Step 3: Sign the app (ad-hoc)
echo ""
echo "🔏 Step 3/4: Signing app (ad-hoc)..."
codesign --force --deep -s - "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
echo "✅ App signed with ad-hoc signature"

# Step 4: Create DMG
echo ""
echo "📀 Step 4/4: Creating DMG..."

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg not found!"
    echo ""
    echo "Please install it with:"
    echo "  brew install create-dmg"
    echo ""
    echo "Or manually from: https://github.com/create-dmg/create-dmg"
    exit 1
fi

# Remove old DMG if exists
rm -f "$DMG_NAME"

# Determine DMG creation options
DMG_OPTS=(
    --volname "$APP_NAME"
    --window-pos 200 120
    --window-size 660 400
    --icon-size 100
    --icon "$APP_NAME.app" 160 185
    --hide-extension "$APP_NAME.app"
    --app-drop-link 500 185
)

# Add background if available
if [ -f "$RESOURCES_DIR/dmg-background.png" ]; then
    DMG_OPTS+=(--background "$RESOURCES_DIR/dmg-background.png")
fi

# Add icon to volume if available
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    DMG_OPTS+=(--volicon "$RESOURCES_DIR/AppIcon.icns")
fi

# Create DMG
create-dmg "${DMG_OPTS[@]}" "$DMG_NAME" "$APP_DIR" 2>&1 | \
    grep -v "^Searching for dmg-license" | \
    grep -v "No such file or directory" || true

echo ""
echo "✅ Build complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 DMG created: $DMG_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Distribution:"
echo "  • Upload to GitHub Releases"
echo "  • Share link with users"
echo ""
echo "Installation (for users):"
echo "  1. Download and open DMG file"
echo "  2. Drag $APP_NAME to Applications"
echo "  3. First launch: System Settings → Privacy & Security → 'Open Anyway'"
echo ""
echo "Note: Ad-hoc signed (no Developer Account required)"
echo "      Users will need to manually approve on first launch."
echo ""
