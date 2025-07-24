#!/bin/bash

# CTriangle Cost Manager - iOS Simulator Fix
# This script works around the Flutter 3.24.3 null check bug in embedFlutterFrameworks

set -e

# Check if this is a simulator build
if [[ "${PLATFORM_NAME}" == "iphonesimulator" ]]; then
    echo "CTriangle: Detected iOS Simulator build - applying workaround for Flutter 3.24.3 bug"
    
    # For simulator builds, we'll use a modified approach that avoids the problematic embedFlutterFrameworks function
    if [[ "${CONFIGURATION}" == "Debug" ]]; then
        # For debug simulator builds, we can skip the embed step as it's not critical
        echo "CTriangle: Skipping embed step for debug simulator build"
        exit 0
    else
        # For release simulator builds, use alternative approach
        echo "CTriangle: Using alternative embed approach for release simulator build"
        /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
        exit 0
    fi
else
    # For physical device builds, use the standard Flutter script
    echo "CTriangle: Physical device build - using standard Flutter backend"
    /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin
fi