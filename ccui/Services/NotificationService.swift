import AppKit
import Foundation
import OSLog
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var authorizationTask: Task<Bool, Never>?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Dispatches a hook event and posts a native notification when the event
    /// represents a moment requiring user attention (permission request).
    func dispatch(event: ClaudeEvent) {
        guard shouldNotify(for: event) else { return }

        let title = notificationTitle(for: event)
        let body = notificationBody(for: event)
        let worktreePath = event.worktreePath

        Task { [weak self] in
            await self?.postNotification(title: title, body: body, worktreePath: worktreePath)
        }
    }

    private func shouldNotify(for event: ClaudeEvent) -> Bool {
        switch event.hookEventName {
        case .permissionRequest:
            return true
        case .notification:
            // Claude Code's Notification hook fires on both permission requests and
            // idle-waiting. The `notification_type` field distinguishes them —
            // permission-related types get a banner; unknown types do too, so we
            // never silently miss an approval prompt.
            guard let type = event.notificationType?.lowercased() else { return true }
            if type.contains("idle") || type.contains("waiting") { return false }
            return true
        default:
            return false
        }
    }

    private func notificationTitle(for event: ClaudeEvent) -> String {
        switch event.hookEventName {
        case .permissionRequest:
            if let tool = event.toolName, !tool.isEmpty {
                return "Claude wants to use \(tool)"
            }
            return "Claude needs permission"
        default:
            return "Claude needs your attention"
        }
    }

    private func notificationBody(for event: ClaudeEvent) -> String {
        let worktreeName = (event.worktreePath as NSString).lastPathComponent
        if let message = event.message, !message.isEmpty {
            return "\(worktreeName): \(message)"
        }
        return worktreeName
    }

    private func postNotification(title: String, body: String, worktreePath: String) async {
        guard await ensureAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["worktreePath": worktreePath]
        // Collapse repeated prompts from the same worktree into one thread.
        content.threadIdentifier = "ccui.permission.\(worktreePath)"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.services.error("Failed to post notification: \(error)")
        }
    }

    private func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            // Concurrent callers share the same authorization request so that
            // notifications arriving during the system prompt aren't dropped.
            if let task = authorizationTask {
                return await task.value
            }
            let task = Task<Bool, Never> {
                do {
                    return try await center.requestAuthorization(options: [.alert, .sound])
                } catch {
                    Logger.services.error("Notification authorization failed: \(error)")
                    return false
                }
            }
            authorizationTask = task
            let result = await task.value
            // Clear after completion so a thrown request can be retried instead
            // of locking us into "false" until the process restarts.
            authorizationTask = nil
            return result
        @unknown default:
            return false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show banners even when ccui is frontmost so an approval prompt isn't missed.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NSApplication.shared.activate()
        }
        completionHandler()
    }
}
