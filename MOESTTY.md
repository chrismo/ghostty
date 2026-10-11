# Moestty

chrismo's personal macOS build of Ghostty, kept on the `moestty` branch of
the `fork` remote and rebased onto upstream `main`.

Build: `zig build` (needs Zig 0.16.x), then run `zig-out/Ghostty.app`.

Install as the daily app: `zig build -Doptimize=ReleaseFast`, remove
`/Applications/Ghostty.app`, and copy `zig-out/Ghostty.app` to
`/Applications/Moestty.app`. This gives up the official app's auto-updates.

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

## Planned

### Mark and move a range of tabs

Use case: chrismo orders tabs by priority with shift+cmd+left/right. Over
time a contiguous group forms, sometimes at an end and sometimes in the
middle, and should move to its own window, usually a new one. Chrome-style
shift-click multi-select was ruled out: native tabs (`NSWindowTabGroup`)
have no multi-select, and building it on AppKit's tab bar is a lot of
custom UI that would conflict on rebase.

Design, a keyboard version of shift-click (like Emacs set-mark):

1. `mark_tab`: set the mark on the current tab and give it a tab color as
   the visible marker (`TerminalWindow.tabColor`, already per tab).
   chrismo doesn't use tab colors otherwise, but restore the previous
   color when the mark clears anyway. Pressing it on the marked tab clears
   the mark.
2. Move to the other end of the group with normal tab navigation.
3. `move_marked_tabs_to_new_window`: move every tab from the mark to the
   current tab, inclusive and in either direction, to a new window in
   their original order. Then clear the mark.

The mark is a single weak reference to one tab. If that tab is closed or
is in another window, the move only moves the current tab. "This tab and
everything to its right" is mark, cmd+9, move, so no separate range action
is needed.

Moving can follow `move_tab_to_new_window`,
`TerminalController.newWindow(tree:)`, and the `detachSurface` /
`moveTabToSplit` patterns in `TerminalController.swift` and
`BaseTerminalController.swift`. Before building, check which tab ends up
focused and whether focus stays in the source window.

### Move marked tabs to an existing window

The command palette picks the target. `jumpOptions` in
`TerminalCommandPalette.swift` already builds a "Focus: <title>" entry per
surface. Add "Move marked tabs to: <window>" entries per window, plus
"Move marked tabs to: New Window". A window without a name is labelled by
its focused tab's title plus the tab count, e.g. "vim … (6 tabs)".

### Named windows

chrismo groups tabs into windows by topic and wants to name those windows.
On macOS a window with tabs is an `NSWindowTabGroup` of separate windows
with no group title, and `prompt_window_title` / `set_window_title` exist
but are Linux-only (`src/input/Binding.zig`).

- Implement `prompt_window_title` and `set_window_title` on macOS. Store
  the name on the tab group, and carry it over as tabs move in or out.
- The command palette is the first place it shows: the name is what
  chrismo types to pick a move target. Showing it in the tab bar or title
  bar can come later, if at all.
- Window menu: Ghostty doesn't customize it (no `changeWindowsItem` or
  `isExcludedFromWindowsMenu`), so AppKit lists one entry per tab, titled
  by the tab, in one flat list with nothing showing which window a tab
  is in (seen 2026-10-11). Prefix each entry with the window name
  ("proj-x — vim") via `NSApp.changeWindowsItem` so the entries group
  visibly. Unnamed windows keep plain tab titles.
- Names are mostly set by hand. Optionally,
  `move_marked_tabs_to_new_window` prompts for a name for the new window.

### AppleScript for a startup layout

Goal: a startup script that builds chrismo's windows, named and with their
tabs. Ghostty already has a scripting dictionary (`macos/Ghostty.sdef`,
`macos/Sources/Features/AppleScript/`) with window, tab and terminal
objects; `new window`, `new tab`, `split` and `select tab` commands; and
`perform action`, which runs any keybind action string, so
`set_tab_title:...` already works. To add:

- A writable window `name` (now read-only, and it returns the selected
  tab's title), backed by the named-windows storage.
- A command to move a tab to another window, e.g.
  `move tab <tab> to window <window>`, for scripts that rearrange tabs
  rather than build windows.

The build order follows the dependencies: mark and move, then named
windows, then palette targets and AppleScript.

## Known bugs (not planned)

- Dragging a split onto the desktop doesn't open it in a new window unless it
  is dropped on the menu bar. `SurfaceDragSource.swift`'s `endedAt` checks
  whether the drop point is inside any visible Ghostty window, and
  background tabs keep their old window frames, so a tab hidden behind a
  window that was later resized still "covers" the desktop.
