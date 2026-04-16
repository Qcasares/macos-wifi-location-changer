import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter.
///
/// Silently no-ops when unauthorised or when called from a context that
/// cannot deliver user notifications (e.g. a raw CLI not embedded in an
/// app bundle), so the headless code path stays working.
public struct Notifier: Sendable {
    public init() {}

    public func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            LocationChangerLog.notifier.error("auth request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(req)
            LocationChangerLog.notifier.info("delivered notification: \(title, privacy: .public)")
        } catch {
            LocationChangerLog.notifier.notice("drop notification (\(title, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fire-and-forget variant callable from sync code.
    public func notifyFireAndForget(title: String, body: String) {
        Task { await self.notify(title: title, body: body) }
    }
}
