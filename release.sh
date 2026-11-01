#!/bin/zsh
# Macht dist/PomodoroBar.zip für ein GitHub-Release. Weigert sich, wenn der Stand nicht dem auf GitHub entspricht.
#   ./release.sh            nur die ZIP bauen
#   ./release.sh --publish  auch taggen, pushen und das Release anlegen
# Vorher die Nummer in VERSION erhöhen und committen. Die Apps finden das Release dann von selbst.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(cat VERSION)"
TAG="v$VERSION"
[[ -z "$(git status --porcelain)" ]] || { echo "❌ Erst alles committen."; exit 1; }
[[ -z "$(git tag -l "$TAG")" ]] || { echo "❌ $TAG gibt es schon: Nummer in VERSION erhöhen."; exit 1; }

./build.sh --no-install
codesign --verify --deep --strict build/PomodoroBar.app

mkdir -p dist
rm -f dist/PomodoroBar.zip
/usr/bin/ditto -c -k --norsrc --noextattr --keepParent build/PomodoroBar.app dist/PomodoroBar.zip
echo "✅ dist/PomodoroBar.zip ($(du -h dist/PomodoroBar.zip | cut -f1)) für $TAG"

if [[ "${1:-}" == "--publish" ]]; then
    git push origin HEAD
    git tag "$TAG"
    git push origin "$TAG"
    gh release create "$TAG" dist/PomodoroBar.zip --title "PomodoroBar $VERSION" --generate-notes
    echo "✅ Veröffentlicht: $TAG"
fi
