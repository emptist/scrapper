#!/bin/bash

# Build script for WebVideoAnalyzer macOS application
set -e  # Exit immediately if a command exits with a non-zero status

echo "Building WebVideoAnalyzer macOS application..."

# Check macOS version compatibility
echo "Checking macOS version compatibility..."
MACOS_VERSION=$(sw_vers -productVersion)
echo "Current macOS version: $MACOS_VERSION"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf .build
rm -rf WebVideoAnalyzer.app

# Build with Swift Package Manager, suppressing specific warnings from Alamofire
echo "Building with Swift Package Manager..."
swift build -c release --arch arm64 --arch x86_64 -Xswiftc -suppress-warnings

# Check if build succeeded
build_output_dir=".build/apple/Products/Release"
if [ ! -d "$build_output_dir" ]; then
    echo "Error: Build output directory not found: $build_output_dir"
    echo "Build failed!"
    exit 1
fi

executable_path="$build_output_dir/WebVideoAnalyzer"
if [ ! -f "$executable_path" ]; then
    echo "Error: Executable not found: $executable_path"
    echo "Available files in build directory:"
    ls -la "$build_output_dir"
    echo "Build failed!"
    exit 1
fi

echo "Build successful! Found executable at: $executable_path"

# Create macOS app bundle
echo "Creating macOS app bundle..."
app_bundle="WebVideoAnalyzer.app"
mkdir -p "$app_bundle/Contents/MacOS"
mkdir -p "$app_bundle/Contents/Resources"

# Create Info.plist with more comprehensive configuration
cat > "$app_bundle/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.webvideoanalyzer</string>
    <key>CFBundleName</key>
    <string>WebVideoAnalyzer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>WebVideoAnalyzer</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) WebVideoAnalyzer</string>
</dict>
</plist>
EOF

# Copy executable
cp "$executable_path" "$app_bundle/Contents/MacOS/"

# Set executable permissions
chmod +x "$app_bundle/Contents/MacOS/WebVideoAnalyzer"

# Verify the app bundle structure
echo "Verifying app bundle structure..."
find "$app_bundle" -type f | sort

echo "macOS application created: $app_bundle"
echo "Bundle size: $(du -sh "$app_bundle" | cut -f1)"
echo "You can now run the app by double-clicking on $app_bundle or by running ./$app_bundle/Contents/MacOS/WebVideoAnalyzer"

# Test the built application
echo "Testing application functionality..."
"./$app_bundle/Contents/MacOS/WebVideoAnalyzer" --help > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Application tests passed successfully!"
else
    echo "✗ Warning: Application test failed!"
    echo "The application was built but may have runtime issues."
fi
