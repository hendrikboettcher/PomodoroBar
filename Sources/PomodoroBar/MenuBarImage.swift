import AppKit

/// Zeichnet Symbol + Zeit als ein einziges Template-Bild für die Menüleiste.
/// So erscheinen beide garantiert, sitzen exakt mittig auf einer Linie,
/// und macOS färbt das Bild automatisch passend (hell/dunkel).
enum MenuBarImage {
    static func make(symbol: String, text: String) -> NSImage {
        let fontSize = NSFont.menuBarFont(ofSize: 0).pointSize
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()

        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = (text as NSString).size(withAttributes: textAttrs)
        let spacing: CGFloat = 4
        let height = max(icon.size.height, textSize.height)
        let size = NSSize(width: ceil(icon.size.width + spacing + textSize.width), height: ceil(height))

        let image = NSImage(size: size, flipped: false) { _ in
            // Symbol und Text jeweils vertikal mittig ausrichten
            icon.draw(in: NSRect(x: 0, y: (height - icon.size.height) / 2,
                                 width: icon.size.width, height: icon.size.height))
            (text as NSString).draw(at: NSPoint(x: icon.size.width + spacing,
                                                y: (height - textSize.height) / 2),
                                    withAttributes: textAttrs)
            return true
        }
        image.isTemplate = true
        return image
    }
}
