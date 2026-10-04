#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "=== Building Tidy with Swift Package Manager ==="
swift build -c release

BIN_PATH="$DIR/.build/release/Tidy"
APP_DIR="$DIR/dist/Tidy.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Packaging $APP_DIR ==="
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/Tidy"
chmod +x "$MACOS_DIR/Tidy"

# Copy Info.plist and PkgInfo
cp "$DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy AppIcon.icns
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy 32-bit RGBA squircle icons
if [ -d "$DIR/Resources/icons" ]; then
    cp -R "$DIR/Resources/icons" "$RESOURCES_DIR/icons"
fi

# Copy download-icons
if [ -d "$DIR/Resources/download-icons" ]; then
    cp -R "$DIR/Resources/download-icons" "$RESOURCES_DIR/download-icons"
fi

# Copy folder icon
if [ -f "$DIR/Resources/tidy-folder-icon.png" ]; then
    cp "$DIR/Resources/tidy-folder-icon.png" "$RESOURCES_DIR/tidy-folder-icon.png"
elif [ -f "$DIR/tidy-folder-icon.png" ]; then
    cp "$DIR/tidy-folder-icon.png" "$RESOURCES_DIR/tidy-folder-icon.png"
fi

# Copy sample icon pack zip
if [ -f "$DIR/my-hero-academia-folder-icons-MAC-wallpapers-clan-com.zip" ]; then
    cp "$DIR/my-hero-academia-folder-icons-MAC-wallpapers-clan-com.zip" "$RESOURCES_DIR/"
fi

# Copy Wallpapers Clan logo
if [ -f "$DIR/Resources/w-clan-logo.png" ]; then
    cp "$DIR/Resources/w-clan-logo.png" "$RESOURCES_DIR/w-clan-logo.png"
fi

# Copy raw SVG icons
if [ -d "$DIR/tidy-icons" ]; then
    cp -R "$DIR/tidy-icons" "$RESOURCES_DIR/svg"
fi

# Copy ALL authentic WebP animations
for webpFile in "$DIR"/*.webp; do
    if [ -f "$webpFile" ]; then
        cp "$webpFile" "$RESOURCES_DIR/"
        echo "Bundled $(basename "$webpFile")"
    fi
done

echo "=== Code signing dist/Tidy.app ==="
codesign --force --deep -s - "$APP_DIR"

echo "=== Tidy.app built successfully at: $APP_DIR ==="
