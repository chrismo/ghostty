# Moestty

chrismo's personal macOS build of Ghostty, kept on the `moestty` branch of
the `fork` remote and rebased onto upstream `main`.

Build: `zig build` (needs Zig 0.16.x), then run `zig-out/Ghostty.app`.

Install as the daily app, with Moestty quit:

```
zig build -Doptimize=ReleaseFast
rm -rf /Applications/Moestty.app && cp -R zig-out/Ghostty.app /Applications/Moestty.app
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$LSR -u "$PWD/macos/build/ReleaseLocal/Ghostty.app"
$LSR -u "$PWD/macos/build/Debug/Ghostty.app"
$LSR -f /Applications/Moestty.app
```

Xcode registers every app it builds with LaunchServices under the same
bundle ID, so without the `lsregister` lines, launching by bundle ID (the
Dock, `open -b`) can start the build-folder copy. That copy shows as
Ghostty in Cmd+Tab, and the next build overwrites it while it runs.
The official app is gone and `auto-update = off` in the config, since an
update would replace Moestty with an official build.

Version: the About window shows the Ghostty version from `build.zig.zon`
and Moestty's own version, `moestty_version` in
`src/build/GhosttyXcodebuild.zig`. Both are set only by `zig build`.

The build still produces `Ghostty.app`, because renaming the product means
many edits to the Xcode project file, which conflict on rebase. The app
shows up as Moestty (Finder, Dock, Cmd+Tab, menu bar) only when the bundle
is named `Moestty.app`. The bundle ID and the `ghostty` executable are
unchanged, so the CLI, shell integration, permissions, and settings carry
over.

## Added keybind actions

- `move_split_to_new_tab`: move the focused split into a new tab next to
  the current one.
- `move_tab_to_split`: move the current tab, with all its splits, into the
  tab on its left (or on its right, from the first tab) as a split to the
  right of that tab's focused split.
- `mark_tab`: mark the current tab as one end of a range of tabs, shown by
  coloring it purple. Pressing it on the marked tab clears the mark. There
  is one mark across all windows.
- `move_marked_tabs_to_new_window`: move the tabs from the mark to the
  current tab, inclusive and in either direction, into a new window, then
  clear the mark. Without a mark in this window, only the current tab
  moves. Focus follows the moved tabs.
- `prompt_window_title` / `set_window_title:<name>`: upstream these are
  Linux-only. On macOS they name the window (the whole tab group); an
  empty name clears it.

## Tab ranges

chrismo orders tabs by priority with shift+cmd+left/right, and over time a
contiguous group forms that belongs in its own window. To move it: mark
one end, go to the other end, then move. "This tab and everything to its
right" is mark, cmd+9, move.

Chrome-style shift-click multi-select was ruled out: native tabs
(`NSWindowTabGroup`) have no multi-select, and building it on AppKit's
tab bar is a lot of custom UI that would conflict on rebase.

Each tab is its own `NSWindow`, so moving tabs regroups windows (AppKit's
`moveTabToNewWindow`, then `addTabbedWindow`) rather than rebuilding
surface trees. Code: `macos/Sources/Features/Terminal/TabMark.swift`. The
mark's color is left out of saved state, so a relaunch doesn't bring back
a stale purple tab.

## Named windows

AppKit has no title for a tab group, so names live in
`macos/Sources/Features/Terminal/WindowNames.swift`, keyed by the group.
A tab that joins a window shares its name; a tab dragged out into a new
window starts unnamed. Names are saved and restored with the window.

Where the name shows:

- Command palette: "Move Tabs to: <window>" for every other window,
  labelled by name, or by the selected tab's title and tab count when
  unnamed ("vim (6 tabs)"). It moves the marked range, or just the
  current tab without a mark, like `move_marked_tabs_to_new_window`
  ("Move Tabs to New Window" in the palette). Typing "move tab" finds both.
- Window menu: AppKit lists every tab on its own, so each tab's entry is
  prefixed with its window's name ("proj-x — vim").
- Not in the tab bar or title bar.

## AppleScript

Ghostty's scripting dictionary (`macos/Ghostty.sdef`) already has window,
tab and terminal objects; `new window`, `new tab`, `split`; and `perform
action`, which runs any keybind action string. Moestty adds:

- A window's `name` is writable and names the window. Reading it returns
  the name, or the selected tab's title when unnamed.
- `move tab <tab> [to <window>]` moves a tab to the end of another window,
  or to a new window when `to` is left out.

So a startup script can build named windows and their tabs.

## Editor ideas

- JetBrains has no first-party Zig support; to try it, use CLion (debugger
  built in) with the third-party ZigBrains plugin and a ZLS matching the
  pinned Zig version. Untested. Swift in `macos/` still needs Xcode.

## Known bugs (not planned)

- Dragging a split onto the desktop doesn't open it in a new window unless it
  is dropped on the menu bar. `SurfaceDragSource.swift`'s `endedAt` checks
  whether the drop point is inside any visible Ghostty window, and
  background tabs keep their old window frames, so a tab hidden behind a
  window that was later resized still "covers" the desktop.
