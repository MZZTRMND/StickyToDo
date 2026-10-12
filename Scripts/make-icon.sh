#!/bin/bash
# Builds AppIcon.icns from Assets/AppIcon.svg and installs it into the given
# app bundles, re-signing each one.
#
#   ./Scripts/make-icon.sh StickyToDo-Test.app
#   ./Scripts/make-icon.sh StickyToDo.app
#
# The SVG is rendered with WebKit (qlmanage) because AppKit's built-in SVG
# support skips the drop-shadow filter; make-icon.swift then cuts the corners,
# applies Apple's 824-on-1024 icon grid, and writes every size.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -eq 0 ]; then
    echo "usage: $0 <App.app> [<App.app> ...]" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Rendering Assets/AppIcon.svg"
cp Assets/AppIcon.svg "$WORK/AppIcon.svg"
qlmanage -t -s 1024 -o "$WORK" "$WORK/AppIcon.svg" >/dev/null 2>&1
[ -f "$WORK/AppIcon.svg.png" ] || { echo "render failed" >&2; exit 1; }

echo "==> Building AppIcon.icns"
swift Scripts/make-icon.swift "$WORK/AppIcon.svg.png" "$WORK/AppIcon.iconset" 2>&1 | grep -v "^warning" || true
iconutil -c icns "$WORK/AppIcon.iconset" -o "$WORK/AppIcon.icns"

for APP in "$@"; do
    echo "==> Installing into $APP"
    cp "$WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    codesign --force --deep -s - "$APP" 2>/dev/null
    codesign --verify --strict "$APP"
    # Nudge Finder/Dock to drop their cached copy of the old icon.
    touch "$APP"
done
