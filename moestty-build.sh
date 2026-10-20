#!/usr/bin/env bash
# Build Moestty and install it as /Applications/Moestty.app.
#
#   ./moestty-build.sh                  build and install
#   ./moestty-build.sh check            build, then run Moestty's Zig tests
#                                       and the macOS app's Swift tests
#   ./moestty-build.sh test-ui [CLASS]  build, then run the macOS UI tests,
#                                       or one class of them, such as
#                                       GhosttyTabSwitcherTests
#   ./moestty-build.sh sync             pick up fork/moestty, rebase onto
#                                       upstream main, then check
#   ./moestty-build.sh bump [VERSION]   set the Moestty version, by default
#                                       bumping the last number (0.2 -> 0.3)

set -euo pipefail

cd "$(dirname "$0")"

version_file=src/build/GhosttyXcodebuild.zig
version_re='^const moestty_version = "([0-9.]+)";$'
app=/Applications/Moestty.app
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

build() {
  zig build -Doptimize=ReleaseFast
}

# Xcode registers each build under the same bundle ID, and the Dock may
# launch that copy instead.
unregister_build_copies() {
  for copy in "$PWD"/macos/build/*/Ghostty.app "$PWD/zig-out/Ghostty.app" \
    ~/Library/Developer/Xcode/DerivedData/Ghostty-*/Build/Products/*/Ghostty.app; do
    "$lsregister" -u "$copy" 2>/dev/null || true
  done
}

install_app() {
  build

  if pgrep -f "$app/Contents/MacOS/ghostty" >/dev/null; then
    echo "Built. Quit Moestty, then run this again to install." >&2
    exit 1
  fi

  rm -rf "$app"
  cp -R zig-out/Ghostty.app "$app"

  unregister_build_copies
  "$lsregister" -f "$app"

  echo "Installed $app"
}

# Opening the Debug app leaves xattrs that fail its next CodeSign.
clear_debug_xattrs() {
  local debug_app
  for debug_app in ~/Library/Developer/Xcode/DerivedData/Ghostty-*/Build/Products/Debug/Ghostty.app; do
    xattr -cr "$debug_app" 2>/dev/null || true
  done
}

check() {
  build

  # Only Moestty's own Zig tests; the full suite is slow.
  local filters=() name
  while IFS= read -r name; do
    filters+=("-Dtest-filter=$name")
  done < <(git diff origin/main...HEAD -- '*.zig' |
    sed -nE 's/^\+[[:space:]]*test "(.*)" \{$/\1/p')
  if ((${#filters[@]})); then
    zig build test "${filters[@]}"
  fi

  clear_debug_xattrs
  (cd macos && env -i PATH="$PATH" xcodebuild test -quiet -scheme Ghostty \
    -skip-testing GhosttyUITests -arch "$(uname -m)")
  unregister_build_copies

  echo "Check passed."
}

test_ui() {
  build

  # The UI tests skip themselves unless Xcode's IDE_DISABLED_OS_ACTIVITY_DT_MODE
  # is set; xcodebuild passes TEST_RUNNER_ variables on without the prefix.
  local only=GhosttyUITests
  [[ -n ${1:-} ]] && only+="/$1"
  echo "The UI tests take over the keyboard and mouse; hands off until they finish." >&2
  clear_debug_xattrs
  (cd macos && env -i PATH="$PATH" HOME="$HOME" TEST_RUNNER_IDE_DISABLED_OS_ACTIVITY_DT_MODE=1 \
    xcodebuild test -quiet -scheme Ghostty -only-testing "$only" -arch "$(uname -m)")
  unregister_build_copies

  echo "UI tests passed."
}

sync_upstream() {
  if [[ $(git branch --show-current) != moestty ]]; then
    echo "Switch to the moestty branch first." >&2
    exit 1
  fi
  if [[ -n $(git status --porcelain) ]]; then
    echo "Commit or stash your changes first." >&2
    exit 1
  fi

  local before
  before=$(git rev-parse --short HEAD)
  local undo="To go back to before the sync: git reset --hard $before"

  git fetch fork moestty
  git fetch origin main

  # --fork-point copes with fork/moestty force-pushed by a sync elsewhere.
  if ! git rebase --fork-point fork/moestty; then
    echo "Conflict with fork/moestty. Resolve it and run git rebase --continue, then sync again." >&2
    echo "$undo" >&2
    exit 1
  fi

  local incoming
  incoming=$(git rev-list --count HEAD..origin/main)
  if ! git rebase origin/main; then
    echo "Conflict with upstream. Resolve it and run git rebase --continue, then ./moestty-build.sh check." >&2
    echo "$undo" >&2
    exit 1
  fi
  echo "Rebased onto $incoming new upstream commits."

  trap 'echo "The check failed on the synced branch. $undo" >&2' EXIT
  check
  trap - EXIT

  echo "Synced. Publish with: git push --force-with-lease fork moestty"
  echo "Install with: ./moestty-build.sh"
}

bump() {
  local current new
  current=$(sed -nE "s/$version_re/\1/p" "$version_file")
  if [[ -z "$current" ]]; then
    echo "No moestty_version found in $version_file" >&2
    exit 1
  fi
  new=${1:-${current%.*}.$((${current##*.} + 1))}
  if [[ ! "$new" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "Version must be numbers and dots, got: $new" >&2
    exit 1
  fi
  sed -i '' -E "s/$version_re/const moestty_version = \"$new\";/" "$version_file"
  echo "Moestty $current -> $new in $version_file"
}

main() {
  case "${1:-}" in
  "") install_app ;;
  check) check ;;
  test-ui) test_ui "${2:-}" ;;
  sync) sync_upstream ;;
  bump) bump "${2:-}" ;;
  *)
    echo "Usage: $0 [check | test-ui [CLASS] | sync | bump [VERSION]]" >&2
    exit 1
    ;;
  esac
}

# sync's rebase rewrites this file while it runs, so bash must have read
# all of it before starting.
main "$@"
exit
