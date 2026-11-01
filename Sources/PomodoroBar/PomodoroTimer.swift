import Foundation
import Combine
import Carbon

enum Phase {
    case focus, rest

    var label: String { self == .focus ? L("phase.focus") : L("phase.break") }
    var symbol: String { self == .focus ? "lightbulb.max" : "cup.and.saucer" }
}

enum TimerState {
    /// waiting: Phase ist abgelaufen, die nächste startet erst nach Bestätigung
    case idle, running, paused, waiting
}

@MainActor
final class PomodoroTimer: ObservableObject {
    // Standard: 4 Runden à 25 min Fokus + 5 min Pause
    let totalRounds = 4
    let focusDuration: TimeInterval = 25 * 60
    let breakDuration: TimeInterval = 5 * 60

    @Published private(set) var state: TimerState = .idle
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var round = 1
    @Published private(set) var remaining: TimeInterval = 25 * 60

    /// Zeitpunkt, an dem die aktuelle Phase endet (nur im Zustand .running).
    /// Die Restzeit wird daraus berechnet, damit der Timer auch nach
    /// Ruhezustand oder verzögerten Ticks exakt bleibt.
    private var endDate: Date?
    private var ticker: Timer?
    private var hotKeys: [GlobalHotKey] = []
    /// true, solange der Schieberegler gezogen wird
    private var isScrubbing = false

    /// Wird aufgerufen, wenn eine Fokusphase von selbst zu Ende läuft.
    /// Übergibt die tatsächlich fokussierte Zeit (Pausen und Spulen zählen nicht).
    var onFocusCompleted: ((TimeInterval) -> Void)?
    private var focusedSeconds: TimeInterval = 0
    private var focusRunningSince: Date?

    init() {
        // Systemweite Kürzel: ⇧⌘P startet/pausiert, ⇧⌘L überspringt die aktuelle Phase
        hotKeys = [
            GlobalHotKey(keyCode: kVK_ANSI_P, modifiers: cmdKey | shiftKey) { [weak self] in
                Task { @MainActor in self?.toggle() }
            },
            GlobalHotKey(keyCode: kVK_ANSI_L, modifiers: cmdKey | shiftKey) { [weak self] in
                Task { @MainActor in self?.skip() }
            },
        ]
        // "Pause starten"/"Fokus starten" direkt aus der Benachrichtigung
        Notifier.shared.onStartNext = { [weak self] in
            Task { @MainActor in self?.start() }
        }
    }

    var phaseDuration: TimeInterval {
        phase == .focus ? focusDuration : breakDuration
    }

    var remainingText: String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var statusLine: String {
        switch state {
        case .idle:
            return L("status.ready", totalRounds, Int(focusDuration / 60))
        case .running, .paused, .waiting:
            return L("status.round", phase.label, round, totalRounds)
        }
    }

    func start() {
        guard state != .running else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        if phase == .focus { focusRunningSince = Date() }
        startTicker()
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    func pause() {
        guard state == .running else { return }
        tick()
        stopTicker()
        stopFocusClock()
        endDate = nil
        state = .paused
    }

    func reset() {
        stopTicker()
        focusedSeconds = 0
        focusRunningSince = nil
        endDate = nil
        state = .idle
        phase = .focus
        round = 1
        remaining = focusDuration
    }

    /// Springt sofort zur nächsten Phase (Fokus → Pause → nächster Fokus).
    /// Ein laufender Timer läuft weiter, ein pausierter/wartender bleibt stehen.
    func skip() {
        guard state != .idle else { return }
        advance(notify: false)
    }

    /// Setzt die Restzeit per Schieberegler. `finished` ist true beim Loslassen.
    /// Wird bis 0 gezogen, endet die Phase wie beim Überspringen (ohne
    /// Benachrichtigung) und die nächste wartet auf Bestätigung.
    func scrub(remaining newValue: TimeInterval, finished: Bool) {
        guard state != .idle else { return }
        isScrubbing = !finished
        remaining = min(max(newValue, 0), phaseDuration)
        if state == .running {
            endDate = Date().addingTimeInterval(remaining)
        }
        guard finished, remaining <= 0 else { return }

        advance(notify: false)
        if state != .idle {
            stopTicker()
            endDate = nil
            state = .waiting
        }
    }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common, damit der Timer auch tickt, während das Menü offen ist
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopFocusClock() {
        if let since = focusRunningSince {
            focusedSeconds += Date().timeIntervalSince(since)
        }
        focusRunningSince = nil
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running, !isScrubbing, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left > 0 {
            // Nur bei Sekundenwechsel publizieren, sonst unnötige Redraws
            if Int(left.rounded(.up)) != Int(remaining.rounded(.up)) {
                remaining = left
            }
        } else {
            advance(notify: true)
        }
    }

    private func advance(notify: Bool) {
        if phase == .focus {
            stopFocusClock()
            // Nur natürlich beendete Fokusphasen zählen, übersprungene nicht
            if notify { onFocusCompleted?(focusedSeconds) }
            focusedSeconds = 0
        }

        switch phase {
        case .focus:
            if notify {
                Notifier.shared.send(title: L("notify.focusDone.title", round, totalRounds),
                                     body: L("notify.focusDone.body", Int(breakDuration / 60)),
                                     startAction: L("action.startBreak"))
            }
            phase = .rest
            remaining = breakDuration
        case .rest:
            if round >= totalRounds {
                if notify {
                    Notifier.shared.send(title: L("notify.allDone.title", totalRounds),
                                         body: L("notify.allDone.body"))
                }
                reset()
                return
            }
            if notify {
                Notifier.shared.send(title: L("notify.breakDone.title"),
                                     body: L("notify.breakDone.body", round + 1, totalRounds, Int(focusDuration / 60)),
                                     startAction: L("action.startFocus"))
            }
            round += 1
            phase = .focus
            remaining = focusDuration
        }
        if notify {
            // Phase von selbst abgelaufen: nächste Phase wartet auf Bestätigung
            stopTicker()
            endDate = nil
            state = .waiting
        } else if state == .running {
            endDate = Date().addingTimeInterval(remaining)
            if phase == .focus { focusRunningSince = Date() }
        }
    }
}
