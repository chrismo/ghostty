#!/usr/bin/env bash
# Build Moestty and install it as /Applications/Moestty.app.

set -euo pipefail

cd "$(dirname "$0")"

app=/Applications/Moestty.app
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

zig build -Doptimize=ReleaseFast

if pgrep -f "$app/Contents/MacOS/ghostty" >/dev/null; then
  echo "Built. Quit Moestty, then run this again to install." >&2
  exit 1
fi

rm -rf "$app"
cp -R zig-out/Ghostty.app "$app"

# Xcode registers each build under the same bundle ID, and the Dock may
# launch that copy instead.
for copy in "$PWD"/macos/build/*/Ghostty.app "$PWD/zig-out/Ghostty.app" \
  ~/Library/Developer/Xcode/DerivedData/Ghostty-*/Build/Products/*/Ghostty.app; do
  "$lsregister" -u "$copy" 2>/dev/null || true
done
"$lsregister" -f "$app"

echo "Installed $app"
