import Foundation
import UserNotifications

/// Handles user notifications for backup completion and failure.
enum NotificationService {
    static func requestAuthorization() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // User denied or error — non-critical
        }
    }

    /// Posts a notification when a backup completes successfully.
    static func postSuccess(for taskName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Backup Complete"
        content.body = "\"\(taskName)\" finished successfully."
        content.sound = nil

        post(content)
    }

    /// Posts a notification when a backup fails.
    static func postFailure(for taskName: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Backup Failed"
        content.body = "\"\(taskName)\" failed: \(error)"
        content.sound = .defaultCritical

        post(content)
    }

    private static func post(_ content: UNNotificationContent) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
