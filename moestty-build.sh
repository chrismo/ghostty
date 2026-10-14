#!/usr/bin/env bash
# Build Moestty and install it as /Applications/Moestty.app.
#
#   ./moestty-build.sh                  build and install
#   ./moestty-build.sh bump [VERSION]   set the Moestty version, by default
#                                       bumping the last number (0.2 -> 0.3)

set -euo pipefail

cd "$(dirname "$0")"

version_file=src/build/GhosttyXcodebuild.zig
version_re='^const moestty_version = "([0-9.]+)";$'

case "${1:-}" in
"") ;;
bump)
  current=$(sed -nE "s/$version_re/\1/p" "$version_file")
  if [[ -z "$current" ]]; then
    echo "No moestty_version found in $version_file" >&2
    exit 1
  fi
  new=${2:-${current%.*}.$((${current##*.} + 1))}
  if [[ ! "$new" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "Version must be numbers and dots, got: $new" >&2
    exit 1
  fi
  sed -i '' -E "s/$version_re/const moestty_version = \"$new\";/" "$version_file"
  echo "Moestty $current -> $new in $version_file"
  exit 0
  ;;
*)
  echo "Usage: $0 [bump [VERSION]]" >&2
  exit 1
  ;;
esac

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
