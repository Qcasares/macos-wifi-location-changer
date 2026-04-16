# LocationChanger

A macOS menubar app that automatically switches your **network location** when
your **Wi-Fi SSID** changes. Useful if you move between networks with different
proxies, DNS, VPN, or service order settings and want those to switch hands-free.

Rewritten from the original bash script for **macOS 14 Sonoma and later**
(including macOS 26 Tahoe) on Apple Silicon. The original used the `airport`
CLI (removed in macOS Sonoma 14.4) and `/usr/local/bin` (Intel Homebrew); those
no longer work, so this is a clean reimplementation in Swift.

## What's in the box

- **LocationChanger.app** — SwiftUI menubar app. Shows current SSID and active
  location; lets you edit SSID → location rules in a Settings window; toggles
  launch-at-login via `SMAppService`.
- **`locationchanger` helper** — Swift CLI embedded in the app bundle at
  `Contents/Helpers/locationchanger`. Can be run standalone from a LaunchAgent
  for a headless, GUI-less installation.
- **`LocationChangerCore`** — shared Swift library with the rule engine,
  config store, Wi-Fi monitor, location switcher, and notifier.

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel Mac (a native-arch build works on either; CI produces
  a universal2 binary)
- Xcode Command Line Tools (`xcode-select --install`) for building from source

## Install

```bash
./install.sh
```

That runs `make app`, copies `build/LocationChanger.app` to `/Applications`,
and launches it. On first run the app will prompt you for:

1. **Location Services** — required. macOS 14+ only exposes the Wi-Fi SSID
   to apps with Location authorization.
2. **Notifications** — optional; controls the "Network Location Changed"
   banner.

Open the menubar icon (Wi-Fi glyph near the top-right) and pick **Settings…**
to configure rules.

## Configure

All settings live in:

```
~/Library/Application Support/LocationChanger/config.json
```

A template is shipped at `config.example.json` at the repo root — copy it to
the path above to pre-seed the config before first launch if you prefer.

Edit rules through the Settings window, or by hand:

```json
{
  "fallback": "Automatic",
  "notificationsEnabled": true,
  "rules": [
    { "id": "…", "ssid": "Home-Wifi-SSID",    "location": "Home" },
    { "id": "…", "ssid": "Company-Wifi-SSID", "location": "Work" }
  ]
}
```

SSID matching is **case-insensitive**. If no rule matches the current SSID,
the `fallback` location is used. Location names must match what's defined in
**System Settings › Network › Locations** — or check from CLI:

```bash
scselect
```

## Headless mode (no GUI)

Install the app once so the helper binary is in place and the code signature
is established, then wire up the LaunchAgent:

```bash
cp /Applications/LocationChanger.app/Contents/Library/LaunchAgents/com.locationchanger.agent.plist \
   ~/Library/LaunchAgents/
launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.locationchanger.agent.plist
```

The agent fires the helper on any change to `State:/Network/Global/IPv4`
(i.e. any network event, not just SSID changes — the helper is idempotent so
that's safe). You can then quit the menubar app or set it not to launch at
login.

To remove:

```bash
launchctl bootout "gui/$UID/com.locationchanger.agent"
rm ~/Library/LaunchAgents/com.locationchanger.agent.plist
```

## Logs

All logging flows through `os.Logger` on the subsystem `com.locationchanger`.
Tail it:

```bash
log stream --predicate 'subsystem == "com.locationchanger"' --level info
```

Or read back recent entries:

```bash
log show --predicate 'subsystem == "com.locationchanger"' --last 10m --style compact
```

## Building

```bash
make build        # release build of both executables (native arch)
make app          # assemble build/LocationChanger.app (includes ad-hoc sign)
make verify       # lipo + codesign verification
make dmg          # wrap the .app in a distributable .dmg
make test         # run the core test runner
make clean
```

Set `DEVELOPER_ID="Developer ID Application: …"` before `make app` to sign
with a real identity. `UNIVERSAL=1` triggers a fat arm64 + x86_64 build (needs
full Xcode; Command Line Tools builds native-arch only).

## Uninstall

```bash
./uninstall.sh              # removes app + config
./uninstall.sh --keep-config  # leaves ~/Library/Application Support/LocationChanger
```

The script asks the app to cleanly unregister itself from launch-at-login
before deletion. You may also want to revoke Location Services and
Notification permissions from System Settings.

## License

MIT. Descended from
[Domenico Silletti's locationchanger](https://github.com/domsi/macos-wifi-location-changer)
script (Rocco Georgi, Onne Gorter).
