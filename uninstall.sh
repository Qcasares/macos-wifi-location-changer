#!/bin/bash
# Remove LocationChanger.app and its data.
#
# Usage: ./uninstall.sh [--keep-config]

set -euo pipefail

APP_DIR="/Applications/LocationChanger.app"
AGENT_LABEL="com.locationchanger.agent"
AGENT_USER_PLIST="$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist"
CONFIG_DIR="$HOME/Library/Application Support/LocationChanger"

KEEP_CONFIG=0
for arg in "$@"; do
    case "$arg" in
        --keep-config) KEEP_CONFIG=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

echo "==> Quitting LocationChanger if running"
osascript -e 'tell application "LocationChanger" to quit' >/dev/null 2>&1 || true

echo "==> Unregistering launch-at-login"
# Try clean SMAppService unregister by launching the app with a flag that
# asks it to unregister and quit. If the app isn't present, skip silently.
if [ -d "$APP_DIR" ]; then
    open -g -a "$APP_DIR" --args --unregister-login-item || true
    sleep 1
fi

echo "==> Unloading optional headless LaunchAgent"
if [ -f "$AGENT_USER_PLIST" ]; then
    launchctl bootout "gui/$UID/${AGENT_LABEL}" 2>/dev/null || true
    rm -f "$AGENT_USER_PLIST"
fi

echo "==> Removing $APP_DIR"
rm -rf "$APP_DIR"

if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo "==> Removing $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
else
    echo "==> Keeping $CONFIG_DIR (--keep-config)"
fi

cat <<EOF

Uninstalled. You may want to revoke Location Services and Notifications
permissions for LocationChanger in:
  System Settings › Privacy & Security › Location Services
  System Settings › Notifications
EOF
