import Foundation
import UserNotifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Wird aufgerufen, wenn in der Benachrichtigung auf "… starten" geklickt wird.
    var onStartNext: (() -> Void)?

    private let startActionID = "START_NEXT"

    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("Benachrichtigungen nicht erlaubt: \(error)") }
            else if !granted { NSLog("Benachrichtigungen vom Nutzer abgelehnt") }
        }
    }

    /// Sendet eine Systembenachrichtigung. Mit `startAction` bekommt sie einen
    /// Button, der die nächste Phase startet.
    func send(title: String, body: String, startAction: String? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                // macOS verweigert der App Benachrichtigungen → Ersatz über AppleScript
                self.sendViaAppleScript(title: title, body: body)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            if let startAction {
                // Kategorie pro Button-Titel, da der Titel je nach Phase wechselt
                let categoryID = "PHASE_END_\(startAction)"
                let action = UNNotificationAction(identifier: self.startActionID, title: startAction, options: [])
                center.setNotificationCategories([
                    UNNotificationCategory(identifier: categoryID, actions: [action], intentIdentifiers: [])
                ])
                content.categoryIdentifier = categoryID
            }

            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func sendViaAppleScript(title: String, body: String) {
        func quoted(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let script = "display notification \(quoted(body)) with title \(quoted(title)) sound name \"Glass\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    // Banner auch anzeigen, wenn die App gerade "aktiv" ist (z. B. Menü offen)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == startActionID {
            onStartNext?()
        }
        completionHandler()
    }
}
