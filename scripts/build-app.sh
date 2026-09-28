#!/bin/sh
# Builds build/Blink.app from the Swift package.
#   --run      launch it afterwards
#   --install  copy it to ~/Applications and launch that copy
#              (use this if you enable "Launch at login": build/ is replaced on every build)
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product Blink
BIN="$(swift build -c release --show-bin-path)/Blink"

APP=build/Blink.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Blink"
cp App/Info.plist "$APP/Contents/Info.plist"
cp -R App/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP" # ad-hoc: enough to run locally
echo "Built $APP"

case "${1:-}" in
--run)
    pkill -x Blink 2>/dev/null || true
    open "$APP"
    ;;
--install)
    pkill -x Blink 2>/dev/null || true
    mkdir -p ~/Applications
    rm -rf ~/Applications/Blink.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/Blink.app
    ;;
esac
