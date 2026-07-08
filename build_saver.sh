#!/bin/bash

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$PROJECT_DIR/WebViewScreenSaver/build/Release"
OUTPUT_DIR="$PROJECT_DIR"
SAVER_NAME="LifeClock.saver"

echo "=== LifeClock Screen Saver Build Script ==="
echo ""

cd "$PROJECT_DIR/WebViewScreenSaver"

echo "Building..."
xcodebuild -project WebViewScreenSaver.xcodeproj -target LifeClock -configuration Release build

if [ $? -eq 0 ]; then
    echo ""
    echo "Build succeeded!"
    echo ""
    
    echo "Copying to $OUTPUT_DIR..."
    rm -rf "$OUTPUT_DIR/$SAVER_NAME"
    cp -R "$BUILD_DIR/LifeClock.saver" "$OUTPUT_DIR/$SAVER_NAME"
    
    echo ""
    echo "Copying updated index.html..."
    cp "$PROJECT_DIR/../index.html" "$OUTPUT_DIR/$SAVER_NAME/Contents/Resources/index.html"
    
    echo ""
    echo "=== Done! ==="
    echo "Output: $OUTPUT_DIR/$SAVER_NAME"
else
    echo ""
    echo "Build failed!"
    exit 1
fi
