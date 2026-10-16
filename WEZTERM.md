# WezTerm vs. Moestty

Notes from 2026-10-15 on whether WezTerm could do what Moestty adds to
Ghostty (see MOESTTY.md). This comes from reading WezTerm's docs, issues and
releases. None of it was tried in WezTerm.

## Built in vs. Moestty

| Moestty feature | WezTerm | How |
|---|---|---|
| `move_split_to_new_tab` | Built in | `pane:move_to_new_tab()`, `PaneSelect{mode="MoveToNewTab"}`, or `wezterm cli move-pane-to-new-tab` |
| Split to new window | Built in | `pane:move_to_new_window()`, `PaneSelect{mode="MoveToNewWindow"}`, or `move-pane-to-new-tab --new-window` |
| `move_tab_to_split` | Single panes only | `wezterm cli split-pane --move-pane-id N` moves one pane into a new split. Nothing grafts a whole tab's split tree. |
| Mark tabs, move to a new or named window | Script it, and layouts are lost | Marks can live in `wezterm.GLOBAL`. The only way across windows is `move-pane-to-new-tab --window-id`, which moves panes, so a tab with splits arrives as separate tabs. There's no "move tab to existing window". |
| Named windows | Built in | `MuxWindow:set_title()` / `get_title()`. Workspaces are also named groups. |
| Window names restored after relaunch | Plugin only | resurrect.wezterm saves window and tab titles and can restore on `gui-startup`. Saving has to be set up, and the repo is archived (the author points to forks). |
| AppleScript `name` / `move tab` | No | WezTerm is scripted with Lua and `wezterm cli`. The docs mention no AppleScript dictionary. |
| `move_split` (arrows over half-split drop zones) | No | The closest are `PaneSelect{mode="SwapWithActive"}` (swap by pane label) and `RotatePanes`. |
| Drag a tab to another window | Not found | Issue #1253 asked for moving tabs between windows and was closed with only the pane-level commands. |

So WezTerm is enough if tabs are mostly single panes. Moving tabs with splits
would flatten them.

## Scripting the rest

Plugins add no extra power. A plugin is a git repo of Lua files loaded into
the config with `wezterm.plugin.require`, using the same API as
`wezterm.lua`. The docs mention no native code and no way to draw UI.

- **Whole tab to split, keeping the layout:** doable, moderate effort.
  `tab:panes_with_info()` gives each pane's `left`, `top`, `width` and
  `height` in cells. `wezterm cli split-pane --pane-id <target>
  --move-pane-id <pane> --left|--right|--top|--bottom --percent N` moves an
  existing pane into a new split. WezTerm's splits are binary trees, so the
  tree can be rebuilt from the geometry: find a cut that runs the full
  length of the tab, then recurse on each side. Then replay the moves one
  pane at a time. Estimated at 100-150 lines of Lua that call `wezterm cli`
  through `wezterm.run_child_process`, since Lua's `pane:split` doesn't
  appear to take an existing pane. Expect split sizes to land a cell or so
  off and the panes to visibly reshuffle while it runs.
- **Mark tabs, move to a window:** easy once the piece above exists. Keep
  the marks in `wezterm.GLOBAL` and show them with the `format-tab-title`
  event. To move a tab, send its first pane with `move-pane-to-new-tab
  --window-id`, then rebuild the rest of the layout the same way.
- **Named windows across relaunch:** `set_title` is built in. To restore
  names after relaunch, use a resurrect fork or write the names to a file
  from Lua. A separate mux server (`unix_domains`) may keep panes alive
  through quitting the app, though not a reboot. That's from memory and
  wasn't checked.
- **`move_split`:** half of it. The move itself can be scripted with a key
  table: arrows pick a neighbor and a side, then `split-pane
  --move-pane-id` does the move. The live half-split highlight can't be
  built, because Lua apparently can't draw over panes. The best substitute
  is showing the target in the status bar.
- **AppleScript:** no. `wezterm cli` replaces it, and anything outside
  WezTerm can call that from the shell.
- **Dragging tabs between windows:** no. That's GUI code, and Lua can't
  reach it.

## Verdict

About three-quarters of Moestty could be done in WezTerm Lua, likely in
fewer lines than the Swift. But that means giving up Ghostty: its native
macOS behavior and the existing config. WezTerm's last stable release is
20240203, so WezTerm users run nightly builds (`main` still gets several
commits a week). Now that Moestty works, switching only pays off if WezTerm
wins on other grounds. To find out, prototype the tab-to-split rebuild
first, since the other tab moves depend on it.

## Sources

- [PaneSelect modes](https://wezterm.org/config/lua/keyassignment/PaneSelect.html)
- [split-pane](https://wezterm.org/cli/cli/split-pane.html)
- [move-pane-to-new-tab](https://wezterm.org/cli/cli/move-pane-to-new-tab.html)
- [Pane methods](https://wezterm.org/config/lua/pane/index.html)
- [MuxWindow methods](https://wezterm.org/config/lua/mux-window/index.html)
- [MuxTab:panes_with_info](https://wezterm.org/config/lua/MuxTab/panes_with_info.html)
- [Plugins](https://wezterm.org/config/plugins.html)
- [Issue #1253](https://github.com/wez/wezterm/issues/1253)
- [Releases](https://github.com/wez/wezterm/releases)
- [resurrect.wezterm](https://github.com/MLFlexer/resurrect.wezterm)
