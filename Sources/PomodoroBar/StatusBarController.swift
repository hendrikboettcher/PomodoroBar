import AppKit
import Combine

/// Menüleisten-Icon und Menü in AppKit. Nötig für den Schieberegler:
/// SwiftUI-Menüs können keine eigenen Elemente wie Slider darstellen.
@MainActor
final class StatusBarController: NSObject {
    private let timer: PomodoroTimer
    private let statsWindow: StatsWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let statusLineItem = NSMenuItem()
    private let scrubberItem = NSMenuItem()
    private let scrubber = ScrubberView()
    private let toggleItem = NSMenuItem()
    private let skipItem = NSMenuItem()
    private let resetItem = NSMenuItem()
    private let updater: Updater
    private let updateItem = NSMenuItem()

    private var cancellables: Set<AnyCancellable> = []

    init(timer: PomodoroTimer, statsWindow: StatsWindowController, updater: Updater) {
        self.timer = timer
        self.statsWindow = statsWindow
        self.updater = updater
        super.init()
        buildMenu()

        updater.onChange = { [weak self] in self?.refreshUpdateItem() }
        refreshUpdateItem()

        scrubber.onScrub = { [weak self] remaining, finished in
            self?.timer.scrub(remaining: remaining, finished: finished)
        }

        // DispatchQueue.main (statt RunLoop.main), damit Updates auch bei offenem Menü ankommen
        timer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        refresh()
    }

    private func buildMenu() {
        menu.autoenablesItems = false

        statusLineItem.isEnabled = false
        scrubberItem.view = scrubber

        toggleItem.target = self
        toggleItem.action = #selector(toggle)
        // Zeigt ⇧⌘P im Menü an; außerhalb des Menüs greift GlobalHotKey (ebenso ⇧⌘L unten)
        toggleItem.keyEquivalent = "p"
        toggleItem.keyEquivalentModifierMask = [.command, .shift]

        configure(skipItem, title: L("menu.skip"), symbol: "forward.end.fill", action: #selector(skip))
        skipItem.keyEquivalent = "l"
        skipItem.keyEquivalentModifierMask = [.command, .shift]
        configure(resetItem, title: L("menu.reset"), symbol: "arrow.counterclockwise", action: #selector(reset))

        let statsItem = NSMenuItem()
        configure(statsItem, title: L("menu.stats"), symbol: "chart.bar.fill", action: #selector(showStats))

        let quitItem = NSMenuItem()
        configure(quitItem, title: L("menu.quit"), symbol: "power", action: #selector(quit))

        configure(updateItem, title: L("menu.checkUpdates"), symbol: "arrow.down.circle", action: #selector(updateClicked))

        let versionItem = NSMenuItem(title: L("menu.version", Updater.currentVersion), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false

        [statusLineItem, scrubberItem, .separator(),
         toggleItem, skipItem, resetItem, .separator(),
         statsItem, updateItem, quitItem, .separator(),
         versionItem].forEach(menu.addItem)

        statusItem.menu = menu
    }

    private func configure(_ item: NSMenuItem, title: String, symbol: String, action: Selector) {
        item.title = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.target = self
        item.action = action
    }

    /// Bringt Menüleiste und Menü auf den aktuellen Stand des Timers.
    private func refresh() {
        // Menüleiste
        if let button = statusItem.button {
            if timer.state == .idle {
                let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "PomodoroBar")
                image?.isTemplate = true
                button.image = image
            } else {
                let symbol = switch timer.state {
                case .paused: "pause.circle"
                case .waiting: "play.circle"
                default: timer.phase.symbol
                }
                button.image = MenuBarImage.make(symbol: symbol, text: timer.remainingText)
            }
        }

        // Menü
        statusLineItem.title = timer.statusLine
        statusLineItem.image = NSImage(systemSymbolName: timer.phase.symbol, accessibilityDescription: nil)

        scrubber.update(remaining: timer.remaining, duration: timer.phaseDuration,
                        text: timer.remainingText, enabled: timer.state != .idle)

        let (title, symbol): (String, String) = switch timer.state {
        case .running: (L("menu.pause"), "pause.fill")
        case .paused: (L("menu.resume"), "play.fill")
        case .idle: (L("menu.start"), "play.fill")
        case .waiting: (L(timer.phase == .rest ? "menu.startBreak" : "menu.startFocus"), "play.fill")
        }
        toggleItem.title = title
        toggleItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)

        skipItem.isEnabled = timer.state != .idle
        resetItem.isEnabled = timer.state != .idle
    }

    private func refreshUpdateItem() {
        if updater.isInstalling {
            updateItem.title = L("menu.updating")
        } else if let release = updater.available {
            updateItem.title = L("menu.updateTo", release.version)
        } else {
            updateItem.title = L("menu.checkUpdates")
        }
        updateItem.isEnabled = !updater.isInstalling
    }

    @objc private func updateClicked() {
        Task {
            do {
                guard let release = try await updater.check() else {
                    showAlert(title: L("update.none.title"), body: L("update.none.body", Updater.currentVersion))
                    return
                }
                if confirmUpdate(to: release) { try await updater.install(release) }
            } catch {
                showAlert(title: L("update.failed.title"), body: L("update.failed.body", error.localizedDescription))
            }
        }
    }

    private func confirmUpdate(to release: Updater.Release) -> Bool {
        let alert = NSAlert()
        alert.messageText = L("update.confirm.title", release.version)
        alert.informativeText = L(timer.state == .idle ? "update.confirm.body" : "update.confirm.bodyRunning")
        alert.addButton(withTitle: L("update.confirm.install"))
        alert.addButton(withTitle: L("update.confirm.later"))
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggle() { timer.toggle() }
    @objc private func skip() { timer.skip() }
    @objc private func reset() { timer.reset() }
    @objc private func showStats() { statsWindow.show() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

/// Menüzeile mit Schieberegler und Restzeit. Der Regler zeigt den Fortschritt
/// der Phase: nach links ziehen = zurückspulen, nach rechts = vorspulen.
/// Er rastet in ganzen Minuten Restzeit ein.
final class ScrubberView: NSView {
    /// (neue Restzeit, Maus losgelassen?)
    var onScrub: ((TimeInterval, Bool) -> Void)?

    private let slider = NSSlider()
    private let label = NSTextField(labelWithString: "")
    private var duration: TimeInterval = 1
    private var isDragging = false

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        autoresizingMask = .width

        slider.minValue = 0
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.translatesAutoresizingMaskIntoConstraints = false

        label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(slider)
        addSubview(label)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 40),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht verwendet") }

    func update(remaining: TimeInterval, duration: TimeInterval, text: String, enabled: Bool) {
        self.duration = duration
        label.stringValue = text
        slider.isEnabled = enabled
        label.textColor = enabled ? .secondaryLabelColor : .tertiaryLabelColor
        // Während des Ziehens nicht dazwischenfunken
        guard !isDragging else { return }
        slider.maxValue = duration
        slider.doubleValue = duration - remaining
    }

    @objc private func sliderMoved() {
        let mouseUp = NSApp.currentEvent?.type == .leftMouseUp || NSEvent.pressedMouseButtons & 1 == 0
        isDragging = !mouseUp

        // Auf ganze Minuten Restzeit einrasten
        let remaining = (max(0, duration - slider.doubleValue) / 60).rounded() * 60
        slider.doubleValue = duration - remaining
        onScrub?(remaining, mouseUp)
    }
}
