#!/bin/zsh
# Builds Browser Swap.app and installs it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Browser Swap.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# App icon from Icon/icon-1024.png (regenerate it with: swift Icon/make-icon.swift Icon/photo.jpg Icon/icon-1024.png)
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s Icon/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) Icon/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
    -o "$APP/Contents/MacOS/browser-swap" Sources/*.swift

codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
    DEST="$HOME/Applications/Browser Swap.app"
    mkdir -p "$HOME/Applications"
    pkill -x browser-swap || true
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
    echo "Installed to $DEST"
fi
