import Foundation

/// Eine abgeschlossene Fokusphase.
struct FocusSession: Codable {
    let date: Date
    let minutes: Int
}

/// Speichert abgeschlossene Pomodoros dauerhaft unter
/// ~/Library/Application Support/PomodoroBar/sessions.json
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [FocusSession] = []

    private let fileURL: URL

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    init(fileURL: URL = SessionStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = saved
        }
    }

    func add(focusedSeconds: TimeInterval) {
        sessions.append(FocusSession(date: Date(), minutes: Int((focusedSeconds / 60).rounded())))
        save()
    }

    private func save() {
        do {
            try JSONEncoder().encode(sessions).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Pomodoros konnten nicht gespeichert werden: \(error)")
        }
    }

    // MARK: Auswertungen

    private var calendar: Calendar { .current }

    func sessions(on day: Date) -> [FocusSession] {
        sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    var thisWeek: [FocusSession] {
        sessions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    /// Tage in Folge mit mindestens einem Pomodoro. Zählt ab heute, oder ab
    /// gestern, falls heute noch keiner geschafft ist.
    var streak: Int {
        var day = calendar.startOfDay(for: Date())
        if sessions(on: day).isEmpty {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while !sessions(on: day).isEmpty {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Pomodoros pro Tag der letzten 7 Tage (ältester zuerst).
    var lastSevenDays: [(day: Date, count: Int, minutes: Int)] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let items = sessions(on: day)
            return (day, items.count, items.reduce(0) { $0 + $1.minutes })
        }
    }
}
