#!/bin/bash

# TDK Dictionary Build Script
# This script builds the macOS app and creates an app bundle

set -e

echo "🔨 Building TDK Dictionary..."

# Clean previous build artifacts to avoid stale module cache issues
rm -rf .build

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

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Sign with a stable identity so macOS permissions (Accessibility, Input
# Monitoring) survive rebuilds. Ad-hoc signatures are keyed to the binary's
# hash, so every rebuild would look like a brand-new app to TCC.
SIGN_IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
if [ -n "${SIGN_IDENTITY}" ]; then
    echo "🔐 Signing with: ${SIGN_IDENTITY}"
    codesign --force --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
    echo "⚠️  No Apple Development identity found; falling back to ad-hoc signing."
    echo "    Accessibility permission will reset on every rebuild."
    codesign --force --sign - "${APP_BUNDLE}"
fi

echo "✅ App bundle created: ${APP_BUNDLE}"
echo ""
echo "🚀 To run the app:"
echo "   open ${APP_BUNDLE}"
echo ""
echo "📁 To install to Applications folder:"
echo "   cp -r ${APP_BUNDLE} /Applications/"
