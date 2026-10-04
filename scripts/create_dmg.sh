#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "=== 1. Building Tidy.app ==="
./scripts/build_app.sh

APP_PATH="$DIR/dist/Tidy.app"
DMG_STAGING="$DIR/dist/dmg_staging"
DMG_RW="$DIR/dist/Tidy_temp.dmg"
DMG_OUTPUT="$DIR/dist/Tidy-v1.2.0.dmg"

echo "=== 2. Generating DMG Background ==="
python3 "$DIR/scripts/create_dmg_background.py"

echo "=== 3. Preparing DMG Contents ==="
rm -rf "$DMG_STAGING" "$DMG_RW" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING/.background"

# Copy background image
cp "$DIR/Resources/dmg_background.png" "$DMG_STAGING/.background/background.png"

# Copy Tidy.app
cp -R "$APP_PATH" "$DMG_STAGING/"

# Applications symlink
ln -s /Applications "$DMG_STAGING/Applications"

# Copy 1-click helper script
cp "$DIR/scripts/open_tidy_helper.sh" "$DMG_STAGING/⚡️ Click Here to Open Tidy.command"
chmod +x "$DMG_STAGING/⚡️ Click Here to Open Tidy.command"

# Copy quick instructions text file
cat << 'EOF' > "$DMG_STAGING/💡 Read If Blocked.txt"
============================================================
  ✨ Welcome to Tidy for Mac!
============================================================

How to Install & Open:
1. Drag "Tidy.app" into the "Applications" folder.
2. Double-click "Tidy" to launch.

If macOS Sequoia displays:
"Apple could not verify Tidy is free of malware..."

Simply do either:
👉 Option 1: Double-click "⚡️ Click Here to Open Tidy" in this folder.
👉 Option 2: Go to System Settings → Privacy & Security → Click "Open Anyway".

Enjoy a sparkling clean Mac!
EOF

echo "=== 4. Creating and Styling Disk Image ==="
# Calculate size needed
SIZE_MB=$(du -sm "$DMG_STAGING" | awk '{print int($1 * 1.3 + 20)}')

# Create Read-Write DMG
hdiutil create -srcfolder "$DMG_STAGING" -volname "Tidy" -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${SIZE_MB}m" "$DMG_RW" -quiet

# Mount the temporary image
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | grep "/Volumes/Tidy" | awk '{print $3}')

if [ -n "$MOUNT_DIR" ]; then
    echo "Configuring Finder window layout for: $MOUNT_DIR"
    
    # Run AppleScript to set visual layout and positions
    osascript -e '
    tell application "Finder"
        tell disk "Tidy"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 120, 860, 540}
            set theView to the icon view options of container window
            set icon size of theView to 88
            set text size of theView to 12
            set arrangement of theView to not arranged
            try
                set background picture of theView to file ".background:background.png"
            end try
            set position of item "Tidy.app" of container window to {160, 140}
            set position of item "Applications" of container window to {500, 140}
            set position of item "⚡️ Click Here to Open Tidy.command" of container window to {330, 245}
            set position of item "💡 Read If Blocked.txt" of container window to {330, 345}
            update without registering applications
            delay 2
            close
        end tell
    end tell' 2>/dev/null || true
    
    # Sync filesystem
    sync
    hdiutil detach "$MOUNT_DIR" -quiet || sleep 2 && hdiutil detach "$MOUNT_DIR" -force -quiet || true
fi

echo "=== 5. Compressing final DMG to UDZO ==="
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUTPUT" -quiet

# Clean temporary files
rm -rf "$DMG_STAGING" "$DMG_RW"

echo "=== ✅ Final DMG Ready: $DMG_OUTPUT ==="
ls -lh "$DMG_OUTPUT"
