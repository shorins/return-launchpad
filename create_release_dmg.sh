#!/bin/bash

# Return Launchpad - Build and DMG Creation Script
# This script automates the entire process from clean build to DMG creation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Return Launchpad"
PROJECT_FILE="Return Launchpad.xcodeproj"
SCHEME="Return Launchpad"
CONFIGURATION="Release"
BUILD_DIR="./build"
APP_NAME="Return Launchpad.app"
DMG_NAME="Return-Launchpad.dmg"
DESKTOP_PATH="$HOME/Desktop"
RELEASE_DIR="$DESKTOP_PATH/Release"

echo -e "${BLUE}🚀 Return Launchpad - Build and DMG Creation Script${NC}"
echo -e "${BLUE}=================================================${NC}\n"

# Function to print step headers
print_step() {
    echo -e "${YELLOW}📋 Step $1: $2${NC}"
    echo "----------------------------------------"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if create-dmg is installed
if ! command_exists create-dmg; then
    echo -e "${RED}❌ Error: create-dmg is not installed${NC}"
    echo -e "${YELLOW}💡 Install it with: brew install create-dmg${NC}"
    exit 1
fi

# Step 1: Clean build
print_step "1" "Cleaning previous build"
echo "Cleaning build artifacts..."
xcodebuild clean \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Clean completed successfully${NC}\n"
else
    echo -e "${RED}❌ Clean failed${NC}"
    exit 1
fi

# Step 2: Build the project
print_step "2" "Building the project"
echo "Building $PROJECT_NAME in $CONFIGURATION configuration..."
xcodebuild build \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully${NC}\n"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Verify the app was built
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Built app not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}📱 App built successfully at: $APP_PATH${NC}\n"

# Step 3: Create Release directory on Desktop
print_step "3" "Creating Release directory"
if [ -d "$RELEASE_DIR" ]; then
    echo "Release directory already exists, removing old version..."
    rm -rf "$RELEASE_DIR"
fi

mkdir -p "$RELEASE_DIR"
echo -e "${GREEN}✅ Created Release directory: $RELEASE_DIR${NC}\n"

# Step 4: Copy app to Release directory
print_step "4" "Copying app to Release directory"
echo "Copying $APP_NAME to Release directory..."
cp -R "$APP_PATH" "$RELEASE_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ App copied successfully${NC}\n"
else
    echo -e "${RED}❌ Failed to copy app${NC}"
    exit 1
fi

# Step 5: Create DMG
print_step "5" "Creating DMG"
echo "Creating DMG installer..."

# Remove existing DMG if it exists
DMG_PATH="$DESKTOP_PATH/$DMG_NAME"
if [ -f "$DMG_PATH" ]; then
    echo "Removing existing DMG..."
    rm "$DMG_PATH"
fi

# Create the DMG
create-dmg \
  --volname "Return Launchpad Installer" \
  --window-size 500 300 \
  --icon-size 100 \
  --icon "$APP_NAME" 120 150 \
  --app-drop-link 380 150 \
  "$DMG_PATH" \
  "$RELEASE_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG created successfully${NC}"
    echo -e "${GREEN}📦 DMG location: $DMG_PATH${NC}\n"
    
    # Clean up the Release directory after successful DMG creation
    echo "🧹 Cleaning up Release directory..."
    rm -rf "$RELEASE_DIR"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Release directory cleaned up${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Warning: Could not remove Release directory${NC}\n"
    fi
else
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

# Get file sizes for summary
APP_SIZE=$(du -sh "$RELEASE_DIR/$APP_NAME" | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)

# Final summary
echo -e "${BLUE}🎉 Build and DMG Creation Complete!${NC}"
echo -e "${BLUE}===================================${NC}"
echo -e "${GREEN}📱 App Size: $APP_SIZE${NC}"
echo -e "${GREEN}📦 DMG Size: $DMG_SIZE${NC}"
echo -e "${GREEN}💿 DMG File: $DMG_PATH${NC}"
echo -e "${GREEN}🧹 Release directory automatically cleaned up${NC}"
echo ""
echo -e "${YELLOW}💡 The DMG is ready for distribution!${NC}"

# Optional: Open the Desktop folder to show the results
read -p "Open Desktop folder to view the results? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$DESKTOP_PATH"
fi

echo -e "${GREEN}🚀 Script completed successfully!${NC}"