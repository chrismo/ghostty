#!/usr/bin/env bash
# Build Moestty and install it as /Applications/Moestty.app.

set -euo pipefail

cd "$(dirname "$0")"

app=/Applications/Moestty.app
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

zig build -Doptimize=ReleaseFast

if pgrep -f "$app/Contents/MacOS/ghostty" >/dev/null; then
  echo "Built. Quit Moestty, then run this again to install (the rebuild is quick)." >&2
  exit 1
fi

rm -rf "$app"
cp -R zig-out/Ghostty.app "$app"

# Xcode registers each build under the same bundle ID, and the Dock may
# launch that copy instead.
"$lsregister" -u "$PWD/macos/build/ReleaseLocal/Ghostty.app" || true
"$lsregister" -u "$PWD/macos/build/Debug/Ghostty.app" || true
"$lsregister" -f "$app"

echo "Installed $app"
