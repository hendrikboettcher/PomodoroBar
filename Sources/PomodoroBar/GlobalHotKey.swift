import AppKit
import Carbon

/// Systemweites Tastenkürzel über die Carbon-Hotkey-API.
/// Funktioniert in jeder App und braucht keine Bedienungshilfen-Freigabe.
///
/// Solange ein Menü dieser App offen ist, wird das Kürzel abgemeldet:
/// Abgefangene Hotkeys werden während der Menü-Bedienung verworfen, so
/// kommt der Tastendruck stattdessen beim passenden Menüeintrag an.
final class GlobalHotKey {
    /// Fortlaufende ID, damit mehrere Kürzel ihre Tastendrücke unterscheiden können
    private static var nextID: UInt32 = 1

    private let id: UInt32
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var observers: [NSObjectProtocol] = []

    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Nicht unser Kürzel → an den nächsten Handler weiterreichen
            guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
            hotKey.action()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                self?.unregister()
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                self?.register()
            },
        ]

        register()
    }

    private func register() {
        guard hotKeyRef == nil else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x504F4D4F) /* "POMO" */, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Tastenkürzel konnte nicht registriert werden (Status \(status)) – evtl. schon belegt")
        }
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
