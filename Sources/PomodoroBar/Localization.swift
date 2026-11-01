import Foundation

/// Lokalisierter Text aus Contents/Resources/<sprache>.lproj/Localizable.strings.
/// macOS wählt die Systemsprache; ohne passende Übersetzung greift Englisch.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}
