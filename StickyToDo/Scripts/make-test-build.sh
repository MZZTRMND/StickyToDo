#!/bin/bash
# Builds StickyToDo-Test.app: a throwaway copy of the app for trying out
# changes without touching the real one.
#
# The test build uses bundle id com.sticky.todo.test, which gives it its own
# UserDefaults domain - so seeding, wiping and stress-testing its task list
# cannot affect the real app's data. Run the real app only once a change has
# been confirmed here.
set -euo pipefail

cd "$(dirname "$0")/.."

TEST_APP="StickyToDo-Test.app"
TEST_BUNDLE_ID="com.sticky.todo.test"

echo "==> Building release binary"
swift build -c release
# --show-bin-path asks SwiftPM for the real output directory instead of
# assuming .build/<triple>/release - that path changed out from under this
# script after a macOS/Xcode update switched swift build's default backend,
# and the copy below silently failed to find anything there.
BIN_PATH="$(swift build -c release --show-bin-path)"

echo "==> Assembling $TEST_APP"
rm -rf "$TEST_APP"
cp -R StickyToDo.app "$TEST_APP"
cp "$BIN_PATH/StickyToDo" "$TEST_APP/Contents/MacOS/StickyToDo"

PLIST="$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $TEST_BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName StickyToDo Test" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName StickyToDo Test" "$PLIST"

echo "==> Signing"
codesign --force --deep -s - "$TEST_APP" 2>/dev/null
codesign --verify --strict "$TEST_APP"

echo
echo "Built $TEST_APP  (bundle id: $TEST_BUNDLE_ID)"
echo "Its data lives in the '$TEST_BUNDLE_ID' defaults domain, separate from the real app."
echo "Launch:      open $TEST_APP"
echo "Reset data:  defaults delete $TEST_BUNDLE_ID"
