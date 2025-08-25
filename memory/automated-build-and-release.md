# Automated Build and DMG Release Workflow

## Overview

This document describes the automated build and DMG creation process for Return Launchpad, implemented in the `create_release_dmg.sh` script. This workflow streamlines the entire process from clean build to distribution-ready DMG with automatic cleanup.

## Workflow Steps

### 1. Clean Build Preparation
```bash
xcodebuild clean \
  -project "Return Launchpad.xcodeproj" \
  -scheme "Return Launchpad" \
  -configuration Release \
  -derivedDataPath ./build
```

**Purpose**: Removes all previous build artifacts to ensure a clean state.

**Benefits**:
- Prevents build cache issues
- Ensures reproducible builds
- Eliminates potential artifacts from previous configurations

### 2. Release Build Execution
```bash
xcodebuild build \
  -project "Return Launchpad.xcodeproj" \
  -scheme "Return Launchpad" \
  -configuration Release \
  -derivedDataPath ./build
```

**Output**: Creates `./build/Build/Products/Release/Return Launchpad.app`

**Configuration Details**:
- Uses Release configuration for optimized build
- Custom derivedDataPath keeps build artifacts local
- Enables all Release optimizations and stripping

### 3. Staging Directory Creation
- Creates `~/Desktop/Release` directory
- Removes existing directory if present to avoid conflicts
- Provides clean staging area for DMG creation

### 4. Application Bundle Copy
- Copies built app from build directory to staging
- Verifies successful copy operation
- Validates app bundle integrity before proceeding

### 5. DMG Creation with Professional Layout
```bash
create-dmg \
  --volname "Return Launchpad Installer" \
  --window-size 500 300 \
  --icon-size 100 \
  --icon "Return Launchpad.app" 120 150 \
  --app-drop-link 380 150 \
  "Return-Launchpad.dmg" \
  "./Release"
```

**DMG Features**:
- Professional installer layout
- Drag-and-drop interface with Applications link
- Optimized window size and icon positioning
- Descriptive volume name for user clarity

### 6. Automatic Cleanup
- **NEW**: Automatically removes the Release directory after successful DMG creation
- Keeps Desktop clean and organized
- Only removes staging directory, preserves the final DMG

## Script Features

### Error Handling
- Exits immediately on any command failure (`set -e`)
- Validates each step before proceeding
- Provides clear error messages with suggestions

### User Experience
- Color-coded output for better readability
- Progress indicators for each step
- File size reporting for built artifacts
- Optional Desktop folder opening

### Prerequisites Validation
- Checks for `create-dmg` installation
- Provides installation instructions if missing
- Validates project structure before proceeding

## Usage

### Basic Usage
```bash
cd "/Users/sergeyshorin/Documents/development/Return Launchpad"
./create_release_dmg.sh
```

### Expected Output
1. **App built**: `./build/Build/Products/Release/Return Launchpad.app`
2. **DMG created**: `~/Desktop/Return-Launchpad.dmg`
3. **Staging cleaned**: Release directory automatically removed

## Technical Benefits

### Build Integrity
- Uses explicit derivedDataPath for consistent builds
- Validates app bundle existence and integrity
- Prevents distribution of corrupted or incomplete builds

### Distribution Quality
- UDZO compression format for optimal file size
- Professional installer appearance
- Consistent naming and versioning

### Developer Productivity
- Single command execution for entire workflow
- Automatic cleanup reduces manual steps
- Reusable across different development environments

## Troubleshooting

### Common Issues

**Build Failures**:
- Ensure Xcode project opens without errors
- Verify development team is selected in project settings
- Check for any compilation errors in the codebase

**DMG Creation Failures**:
- Install create-dmg: `brew install create-dmg`
- Ensure sufficient disk space on Desktop
- Verify Release directory contains valid app bundle

**Permission Issues**:
- Ensure script is executable: `chmod +x create_release_dmg.sh`
- Verify write permissions to Desktop
- Check Xcode command line tools installation

### File Size Validation
- Built app should be approximately 1.6MB (not 31KB indicating corruption)
- DMG should be compressed but reasonable size
- Monitor for unusual file sizes indicating build issues

## Integration with CI/CD

This script can be integrated into automated workflows:

```bash
# Example CI/CD integration
#!/bin/bash
set -e

# Run automated build and DMG creation
./create_release_dmg.sh

# Upload DMG to release artifacts
# (Add your CI/CD specific upload commands here)
```

## Version History

- **v1.0**: Initial implementation with manual cleanup
- **v1.1**: Added automatic Release directory cleanup after DMG creation
- **Future**: Consider adding version number injection and automated signing

## Related Files

- `create_release_dmg.sh` - Main automation script
- `create_dmg.sh` - Legacy DMG creation script
- `create_simple_dmg.sh` - Simple DMG creation alternative