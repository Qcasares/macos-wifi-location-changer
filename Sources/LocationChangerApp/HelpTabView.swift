import SwiftUI
import AppKit

struct HelpTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                quickStart
                howItWorks
                findingThings
                permissions
                troubleshooting
                about
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.square.fill")
                    .foregroundStyle(.tint)
                    .font(.title)
                Text("Welcome to LocationChanger").font(.title2.bold())
            }
            Text("Automatically switch your macOS network location when you join a known Wi-Fi network. Useful when different networks need different DNS, proxy, VPN order, or service configurations.")
                .foregroundStyle(.secondary)
        }
    }

    private var quickStart: some View {
        helpSection("Quick start") {
            numberedList([
                "Open **System Settings › Network** and make sure you have more than one location (click the popup next to *Location* → *Edit Locations…*).",
                "Come back to the **Rules** tab here and click *Add rule*.",
                "Type the Wi-Fi SSID you want to match and pick a target location.",
                "Save. LocationChanger will switch automatically next time you join that network.",
            ])
        }
    }

    private var howItWorks: some View {
        helpSection("How rules work") {
            bulletedList([
                "Rules are evaluated top-to-bottom. **First match wins** — drag to reorder.",
                "SSID matching is **case-insensitive** and exact (no wildcards yet).",
                "When no rule matches, the **fallback location** (in the *General* tab) is applied.",
                "When Wi-Fi is off or the SSID is hidden, the fallback applies too.",
                "Duplicate SSIDs are flagged in red — only the first one can ever fire.",
            ])
        }
    }

    private var findingThings: some View {
        helpSection("Finding your SSID and location names") {
            VStack(alignment: .leading, spacing: 8) {
                bulletedList([
                    "**Current SSID:** click the Wi-Fi icon in the menu bar — the connected network has a checkmark.",
                    "**Defined network locations:** in System Settings › Network, click the popup next to *Location*. The names listed there are what LocationChanger uses.",
                ])
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open Network settings", systemImage: "arrow.up.forward.square")
                }
            }
        }
    }

    private var permissions: some View {
        helpSection("Permissions") {
            VStack(alignment: .leading, spacing: 8) {
                Text("macOS 14+ only reveals the Wi-Fi SSID to apps with **Location Services** authorization. Without it, LocationChanger can't tell which network you're on and will always fall back.")
                    .font(.callout)
                bulletedList([
                    "If the menubar icon shows an **exclamation mark**, Location Services is missing.",
                    "The **notification** permission is optional — it controls the banner you see on a successful switch.",
                ])
                HStack(spacing: 10) {
                    Button {
                        openURLString("x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
                    } label: {
                        Label("Location Services", systemImage: "location")
                    }
                    Button {
                        openURLString("x-apple.systempreferences:com.apple.preference.notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }
            }
        }
    }

    private var troubleshooting: some View {
        helpSection("Troubleshooting") {
            VStack(alignment: .leading, spacing: 12) {
                troubleshootingEntry(
                    title: "SSID shows as '—' in the menubar",
                    steps: [
                        "Make sure Wi-Fi is on and connected.",
                        "Check that LocationChanger has Location Services permission.",
                        "Open the menu once — first-click prompts the permission dialog.",
                    ]
                )
                troubleshootingEntry(
                    title: "Rule isn't firing",
                    steps: [
                        "Compare the rule's SSID to the name shown in the menubar status card — matching is case-insensitive but otherwise exact.",
                        "Check the rule's status dot. Green = matched now; red = duplicate hides it; orange = target location doesn't exist in System Settings.",
                        "If you just added a new network location in System Settings, return to this window — the picker auto-refreshes on focus.",
                    ]
                )
                troubleshootingEntry(
                    title: "App doesn't start after reboot",
                    steps: [
                        "Turn on *Launch LocationChanger at login* in the General tab.",
                    ]
                )
            }
        }
    }

    private var about: some View {
        helpSection("About") {
            VStack(alignment: .leading, spacing: 6) {
                Text("LocationChanger \(Bundle.main.shortVersion) — MIT license.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    openURLString("https://github.com/Qcasares/macos-wifi-location-changer")
                } label: {
                    Label("Open repository on GitHub", systemImage: "arrow.up.forward.square")
                }
            }
        }
    }

    // MARK: - Helpers

    private func helpSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    private func troubleshootingEntry(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.bold())
            bulletedList(steps)
        }
    }

    private func bulletedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    Text(markdownText(item))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func numberedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit()
                    Text(markdownText(item))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func markdownText(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    private func openURLString(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
