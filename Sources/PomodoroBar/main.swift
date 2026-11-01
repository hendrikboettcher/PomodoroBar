import AppKit

// Reine AppKit-App: Menüleisten-Icon + natives Menü (siehe StatusBarController).
// Kein Dock-Icon dank LSUIElement in der Info.plist.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
