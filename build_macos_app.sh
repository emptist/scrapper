#!/bin/bash

# Build script for WebVideoAnalyzer macOS application

echo "Building WebVideoAnalyzer macOS application..."

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf .build
rm -rf WebVideoAnalyzer.app

# Build with Swift Package Manager
echo "Building with Swift Package Manager..."
swift build -c release --arch arm64 --arch x86_64

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build successful!"
    
    # Create app bundle structure
    echo "Creating macOS app bundle..."
    mkdir -p WebVideoAnalyzer.app/Contents/MacOS
    mkdir -p WebVideoAnalyzer.app/Contents/Resources
    
    # Copy executable to app bundle
    cp .build/apple/Products/Release/WebVideoAnalyzer WebVideoAnalyzer.app/Contents/MacOS/
    
    # Create Info.plist
    cat > WebVideoAnalyzer.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>WebVideoAnalyzer</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.WebVideoAnalyzer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>WebVideoAnalyzer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 WebVideoAnalyzer. All rights reserved.</string>
</dict>
</plist>
EOF

    # Create basic app icon directory
    mkdir -p WebVideoAnalyzer.app/Contents/Resources
    
    # Make executable
    chmod +x WebVideoAnalyzer.app/Contents/MacOS/WebVideoAnalyzer
    
    echo "macOS application created: WebVideoAnalyzer.app"
    echo "You can now run the app by double-clicking on WebVideoAnalyzer.app or by running ./WebVideoAnalyzer.app/Contents/MacOS/WebVideoAnalyzer"
else
    echo "Build failed!"
    exit 1
fi