#!/bin/zsh
# Builds Browser Swap.app and installs it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Browser Swap.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

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
