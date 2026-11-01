#!/bin/zsh
# Baut PomodoroBar.app (ohne Xcode, nur Command Line Tools nötig) und installiert sie.
#   ./build.sh               bauen und nach /Applications installieren
#   ./build.sh --no-install  nur bauen (für release.sh)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/PomodoroBar.app"
VERSION="$(cat VERSION)"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/PomodoroBar" "$APP/Contents/MacOS/PomodoroBar"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PomodoroBar</string>
    <key>CFBundleDisplayName</key><string>PomodoroBar</string>
    <key>CFBundleIdentifier</key><string>com.hendrik.PomodoroBar</string>
    <key>CFBundleExecutable</key><string>PomodoroBar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$(date +%Y%m%d%H%M%S)</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>de</string></array>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Kein Dock-Icon, kein App-Menü: reine Menüleisten-App -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# App-Icon (neu erzeugen: swift Icon/make_icon.swift Icon/AppIcon.png, dann .icns bauen)
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Übersetzungen (macOS wählt automatisch die Systemsprache, sonst Englisch)
cp -R Localization/*.lproj "$APP/Contents/Resources/"

# Ad-hoc-Signatur (nötig für Benachrichtigungen)
chmod -R g+w "$APP"
codesign --force --deep --sign - "$APP"
echo "✅ Fertig: $APP ($VERSION)"

[[ "${1:-}" == "--no-install" ]] && exit 0

# Nach /Applications installieren und die Kopie im build-Ordner bei macOS
# abmelden, damit es nur eine registrierte PomodoroBar gibt
pkill -f "PomodoroBar.app/Contents/MacOS/PomodoroBar" || true
rm -rf /Applications/PomodoroBar.app
cp -R "$APP" /Applications/
# Gruppe admin darf schreiben, damit auch andere Admin-Accounts dieses Macs die App aktualisieren können
chmod -R g+w /Applications/PomodoroBar.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -u "$APP" 2>/dev/null || true
"$LSREGISTER" -f /Applications/PomodoroBar.app
echo "✅ Installiert: /Applications/PomodoroBar.app"
