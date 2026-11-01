import AppKit
import Charts
import SwiftUI

/// Fenster mit der Pomodoro-Statistik, geöffnet über "Statistik…" im Menü.
@MainActor
final class StatsWindowController {
    private let sessions: SessionStore
    private var window: NSWindow?

    init(sessions: SessionStore) {
        self.sessions = sessions
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: StatsView(store: sessions)))
            window.title = L("stats.title")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Menüleisten-Apps sind nie "vorne" – Fenster aktiv nach vorne holen
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct StatsView: View {
    @ObservedObject var store: SessionStore
    @State private var hoveredDay: Date?

    var body: some View {
        let today = store.sessions(on: Date())
        let week = store.thisWeek

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 10) {
                StatTile(symbol: "sun.max", title: L("stats.today"),
                         value: "\(today.count)", detail: minutesText(today))
                StatTile(symbol: "calendar", title: L("stats.week"),
                         value: "\(week.count)", detail: minutesText(week))
                StatTile(symbol: "flame", title: L("stats.streak"),
                         value: "\(store.streak)", detail: L(store.streak == 1 ? "stats.day" : "stats.days"))
                StatTile(symbol: "sum", title: L("stats.total"),
                         value: "\(store.sessions.count)", detail: minutesText(store.sessions))
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("stats.last7"))
                    .font(.headline)
                chart
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var chart: some View {
        let days = store.lastSevenDays
        return Chart(days, id: \.day) { item in
            BarMark(x: .value("Day", item.day, unit: .day),
                    y: .value("Pomodoros", item.count),
                    width: .ratio(0.55))
                .cornerRadius(4)
                .foregroundStyle(Color.accentColor.opacity(hoveredDay == nil || hoveredDay == item.day ? 1 : 0.45))
                .annotation(position: .top, spacing: 4) {
                    if hoveredDay == item.day {
                        Text(L("stats.tooltip", item.count, item.minutes))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartYScale(domain: 0...max(4, (days.map(\.count).max() ?? 0) + 1))
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let x = location.x - geo[proxy.plotAreaFrame].origin.x
                            if let date: Date = proxy.value(atX: x) {
                                hoveredDay = Calendar.current.startOfDay(for: date)
                            }
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
        .overlay {
            if store.sessions.isEmpty {
                Text(L("stats.empty"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
    }

    private func minutesText(_ items: [FocusSession]) -> String {
        L("stats.minutes", items.reduce(0) { $0 + $1.minutes })
    }
}

private struct StatTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
