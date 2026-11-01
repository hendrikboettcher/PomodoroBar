import AppKit

/// Sucht auf GitHub nach neuen Versionen und tauscht die laufende App gegen die neue aus.
/// Die Statistik liegt außerhalb der App (siehe SessionStore) und bleibt erhalten.
@MainActor
final class Updater {
    struct Release {
        let version: String
        let zipURL: URL
    }

    enum UpdateError: LocalizedError {
        case badResponse
        case invalidDownload

        var errorDescription: String? {
            switch self {
            case .badResponse: L("update.error.response")
            case .invalidDownload: L("update.error.download")
            }
        }
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
        let tagName: String
        let assets: [Asset]
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/hendrikboettcher/PomodoroBar/releases/latest")!
    private static let zipName = "PomodoroBar.zip"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private(set) var available: Release? {
        didSet { onChange?() }
    }
    private(set) var isInstalling = false {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?

    private var checkTimer: Timer?

    /// Sucht beim Start und danach einmal täglich; Fehler (z. B. offline) bleiben hier still.
    func startBackgroundChecks() {
        Task { _ = try? await check() }
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in _ = try? await self?.check() }
        }
    }

    /// Gibt die neuere Version zurück oder nil, wenn diese App aktuell ist.
    @discardableResult
    func check() async throws -> Release? {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let latest = try decoder.decode(GitHubRelease.self, from: data)
        guard let zip = latest.assets.first(where: { $0.name == Self.zipName }) else { throw UpdateError.badResponse }

        let version = latest.tagName.hasPrefix("v") ? String(latest.tagName.dropFirst()) : latest.tagName
        let isNewer = version.compare(Self.currentVersion, options: .numeric) == .orderedDescending
        available = isNewer ? Release(version: version, zipURL: zip.browserDownloadUrl) : nil
        return available
    }

    /// Lädt die Version, prüft sie, tauscht die App aus und startet neu.
    /// Kehrt nur im Fehlerfall zurück; die bisherige App bleibt dann an ihrem Platz.
    func install(_ release: Release) async throws {
        isInstalling = true
        defer { isInstalling = false }

        let fileManager = FileManager.default
        let target = Bundle.main.bundleURL
        // Liegt auf demselben Volume wie die App, damit der Austausch ein schnelles Umbenennen ist
        let staging = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                          appropriateFor: target, create: true)
        defer { try? fileManager.removeItem(at: staging) }

        let (zip, response) = try await URLSession.shared.download(from: release.zipURL)
        defer { try? fileManager.removeItem(at: zip) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        try await Self.run("/usr/bin/ditto", "-x", "-k", zip.path, staging.path)

        let new = staging.appendingPathComponent("PomodoroBar.app")
        guard let bundle = Bundle(url: new),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.version
        else { throw UpdateError.invalidDownload }
        try await Self.run("/usr/bin/codesign", "--verify", "--deep", "--strict", new.path)

        let old = staging.appendingPathComponent("Old.app")
        try fileManager.moveItem(at: target, to: old)
        do {
            try fileManager.moveItem(at: new, to: target)
        } catch {
            try? fileManager.moveItem(at: old, to: target)
            throw error
        }
        try? fileManager.removeItem(at: staging)

        try Self.relaunchAfterExit(at: target)
        NSApplication.shared.terminate(nil)
    }

    /// Eine kleine Shell wartet, bis diese App beendet ist, und öffnet dann die neue.
    private static func relaunchAfterExit(at app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \"$0\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open -n \"$1\"",
                             String(ProcessInfo.processInfo.processIdentifier), app.path]
        try process.run()
    }

    private static func run(_ tool: String, _ arguments: String...) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw UpdateError.invalidDownload }
        }.value
    }
}
