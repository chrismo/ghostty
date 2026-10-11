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

## Known bugs (not planned)

- Dragging a split onto the desktop doesn't open it in a new window unless it
  is dropped on the menu bar. `SurfaceDragSource.swift`'s `endedAt` checks
  whether the drop point is inside any visible Ghostty window, and
  background tabs keep their old window frames, so a tab hidden behind a
  window that was later resized still "covers" the desktop.
