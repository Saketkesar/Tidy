#!/bin/bash

clear
echo "============================================================"
echo "  ✨ Welcome to Tidy for Mac!"
echo "============================================================"
echo ""

APP_DEST="/Applications/Tidy.app"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_SRC="$DIR/Tidy.app"

if [ ! -d "$APP_DEST" ]; then
    if [ -d "$APP_SRC" ]; then
        echo "  📦 Copying Tidy to your /Applications folder..."
        cp -R "$APP_SRC" /Applications/
        echo "  ✅ Installed to /Applications!"
    fi
fi

if [ -d "$APP_DEST" ]; then
    echo "  🔓 Authorizing Tidy for macOS Gatekeeper..."
    xattr -cr "$APP_DEST" 2>/dev/null || true
    echo "  ✅ Authorized successfully!"
    echo ""
    echo "  🚀 Launching Tidy..."
    open "$APP_DEST"
    echo ""
    echo "  ✨ Tidy is now open! You can close this window."
    sleep 2
    osascript -e 'tell application "Terminal" to close front window' & exit 0
else
    echo "  ⚠️  Could not find Tidy.app. Please drag Tidy into Applications first."
    read -p "  Press Enter to exit..."
fi
