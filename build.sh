#!/bin/bash

# TDK Dictionary Build Script
# This script builds the macOS app and creates an app bundle

set -e

echo "🔨 Building TDK Dictionary..."

# Build the project
swift build -c release

echo "✅ Build complete!"
echo ""
echo "📦 Creating app bundle..."

# Create app bundle structure
APP_NAME="TDKDictionary"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Remove existing bundle
rm -rf "${APP_BUNDLE}"

# Create directories
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"

# Copy Info.plist
cp "Sources/${APP_NAME}/Info.plist" "${CONTENTS_DIR}/"

# Copy entitlements (optional, for code signing)
if [ -f "Sources/${APP_NAME}/${APP_NAME}.entitlements" ]; then
    cp "Sources/${APP_NAME}/${APP_NAME}.entitlements" "${CONTENTS_DIR}/"
fi

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "✅ App bundle created: ${APP_BUNDLE}"
echo ""
echo "🚀 To run the app:"
echo "   open ${APP_BUNDLE}"
echo ""
echo "📁 To install to Applications folder:"
echo "   cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "🔐 To code sign (optional):"
echo "   codesign --deep --force --verify --verbose --sign - ${APP_BUNDLE}"
