import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let sessions = SessionStore()
    private let updater = Updater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.shared.setUp()

        let timer = PomodoroTimer()
        timer.onFocusCompleted = { [sessions] seconds in sessions.add(focusedSeconds: seconds) }
        statusBar = StatusBarController(timer: timer, statsWindow: StatsWindowController(sessions: sessions), updater: updater)
        updater.startBackgroundChecks()

        // Zum Testen: open -a PomodoroBar --args --test-notification
        if CommandLine.arguments.contains("--test-notification") {
            Notifier.shared.send(title: L("notify.focusDone.title", 1, 4),
                                 body: L("notify.focusDone.body", 5),
                                 startAction: L("action.startBreak"))
        }

        // Zum Testen: installiert eine neuere Version ohne Rückfrage
        if CommandLine.arguments.contains("--test-update") {
            Task { [updater] in
                do {
                    if let release = try await updater.check() { try await updater.install(release) }
                    NSLog("--test-update: keine neuere Version")
                } catch {
                    NSLog("--test-update fehlgeschlagen: \(error)")
                }
            }
        }
    }
}
