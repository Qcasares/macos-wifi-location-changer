#!/bin/bash
# Build and install LocationChanger.app into /Applications.
#
# Usage: ./install.sh
#
# Requires: macOS 14+ (Sonoma), Swift toolchain (`xcode-select --install` or
# full Xcode). Launch-at-login is registered by the app itself via
# SMAppService the first time you toggle it in Settings.

set -euo pipefail

cd "$(dirname "$0")"

APP_DIR="/Applications/LocationChanger.app"
BUILD_APP="build/LocationChanger.app"

echo "==> Building LocationChanger.app"
make app

if [ ! -d "$BUILD_APP" ]; then
    echo "build failed: $BUILD_APP not found" >&2
    exit 1
fi

echo "==> Installing to $APP_DIR"
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi
cp -R "$BUILD_APP" "$APP_DIR"

CONFIG_DIR="$HOME/Library/Application Support/LocationChanger"
CONFIG_FILE="$CONFIG_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ] && [ -f config.example.json ]; then
    echo "==> Seeding default config at $CONFIG_FILE"
    mkdir -p "$CONFIG_DIR"
    cp config.example.json "$CONFIG_FILE"
fi

echo "==> Launching LocationChanger"
open "$APP_DIR"

cat <<EOF

Installed. On first launch macOS will prompt for:
  - Location Services authorization (required to read the SSID on macOS 14+)
  - Notification authorization (optional; controls the "location changed" banner)

Open the menubar icon (Wi-Fi glyph in the top-right) to edit rules and toggle
"Launch at login".

To switch to the headless / CLI-only mode, see README.md.
EOF
