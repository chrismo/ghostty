# Moestty

chrismo's personal macOS build of Ghostty, kept on the `moestty` branch of
the `fork` remote and rebased onto upstream `main`.

Build: `zig build` (needs Zig 0.16.x), then run `zig-out/Ghostty.app`.

## Added keybind actions

- `move_split_to_new_tab`: move the focused split into a new tab next to
  the current one.

## Planned

- `move_tab_to_split`: move the current tab into the tab on its left as a
  split.

## Known bugs (not planned)

- Dragging a split onto the desktop doesn't open it in a new window unless it
  is dropped on the menu bar. `SurfaceDragSource.swift`'s `endedAt` checks
  whether the drop point is inside any visible Ghostty window, and
  background tabs keep their old window frames, so a tab hidden behind a
  window that was later resized still "covers" the desktop.
