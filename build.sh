#!/bin/bash
set -euo pipefail

# Build SensibleSideButtons from the command line
# Requires: Xcode (full install, not just Command Line Tools)

BUILD_DIR="build"
CONFIG="${1:-Release}"
APP_NAME="SensibleSideButtons"

echo "==> Building $APP_NAME ($CONFIG)..."

xcodebuild \
    -project SwipeSimulator.xcodeproj \
    -target SideButtonFixer \
    -configuration "$CONFIG" \
    -arch arm64 -arch x86_64 \
    SYMROOT="$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    | tail -5

APP_PATH="$BUILD_DIR/$CONFIG/$APP_NAME.app"

if [ -d "$APP_PATH" ]; then
    echo "==> Build succeeded: $APP_PATH"
    echo ""
    echo "To run:  open $APP_PATH"
    echo "To install: cp -R $APP_PATH /Applications/"
else
    echo "==> Build failed."
    exit 1
fi
