import UserNotifications

/// Local notifications for incoming school requests (driven by Supabase Realtime).
/// Real push would need APNs; for the demo, the app hears the request over Realtime.
final class Notifications: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = Notifications()

    func setUp() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schoolRequested(_ school: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(school) wants your vaccine proof"
        content.body = "Review and approve on your Ledger. Your records stay private."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Show banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    {
        [.banner, .sound, .list]
    }
}
