#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "=== Building Tidy.app ==="
./scripts/build_app.sh

APP_PATH="$DIR/dist/Tidy.app"
DMG_DIR="$DIR/dist/dmg_temp"
DMG_OUTPUT="$DIR/dist/Tidy-v1.2.0.dmg"

echo "=== Preparing DMG staging directory ==="
rm -rf "$DMG_DIR" "$DMG_OUTPUT"
mkdir -p "$DMG_DIR"

cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

echo "=== Creating Disk Image: $DMG_OUTPUT ==="
hdiutil create -volname "Tidy" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_OUTPUT"

rm -rf "$DMG_DIR"
echo "=== DMG created successfully at: $DMG_OUTPUT ==="
