# WezTerm vs. Moestty

Notes from 2026-10-15 on whether WezTerm could do what Moestty adds to
Ghostty (see MOESTTY.md). This comes from reading WezTerm's docs, issues and
releases. None of it was tried in WezTerm.

## Built in vs. Moestty

| Moestty feature                                  | WezTerm                         | How                                                                                                                                                                                                                |
| ------------------------------------------------ | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `move_split_to_new_tab`                          | Built in                        | `pane:move_to_new_tab()`, `PaneSelect{mode="MoveToNewTab"}`, or `wezterm cli move-pane-to-new-tab`                                                                                                                 |
| Split to new window                              | Built in                        | `pane:move_to_new_window()`, `PaneSelect{mode="MoveToNewWindow"}`, or `move-pane-to-new-tab --new-window`                                                                                                          |
| `move_tab_to_split`                              | Single panes only               | `wezterm cli split-pane --move-pane-id N` moves one pane into a new split. Nothing grafts a whole tab's split tree.                                                                                                |
| Mark tabs, move to a new or named window         | Script it, and layouts are lost | Marks can live in `wezterm.GLOBAL`. The only way across windows is `move-pane-to-new-tab --window-id`, which moves panes, so a tab with splits arrives as separate tabs. There's no "move tab to existing window". |
| Named windows                                    | Built in                        | `MuxWindow:set_title()` / `get_title()`. Workspaces are also named groups.                                                                                                                                         |
| Window names restored after relaunch             | Plugin only                     | resurrect.wezterm saves window and tab titles and can restore on `gui-startup`. Saving has to be set up, and the repo is archived (the author points to forks).                                                    |
| AppleScript `name` / `move tab`                  | No                              | WezTerm is scripted with Lua and `wezterm cli`. The docs mention no AppleScript dictionary.                                                                                                                        |
| `move_split` (arrows over half-split drop zones) | No                              | The closest are `PaneSelect{mode="SwapWithActive"}` (swap by pane label) and `RotatePanes`.                                                                                                                        |
| Drag a tab to another window                     | Not found                       | Issue #1253 asked for moving tabs between windows and was closed with only the pane-level commands.                                                                                                                |

So WezTerm is enough if tabs are mostly single panes. Moving tabs with splits
would flatten them.

## Scripting the rest

Plugins add no extra power. A plugin is a git repo of Lua files loaded into
the config with `wezterm.plugin.require`, using the same API as
`wezterm.lua`. The docs mention no native code and no way to draw UI.

- **Whole tab to split, keeping the layout:** doable, moderate effort.
  `tab:panes_with_info()` gives each pane's `left`, `top`, `width` and
  `height` in cells. This moves an existing pane into a new split:

  ```sh
  wezterm cli split-pane --pane-id <target> --move-pane-id <pane> \
    --left|--right|--top|--bottom --percent N
  ```

  WezTerm's splits are binary trees, so the tree can be rebuilt from the
  geometry: find a cut that runs the full length of the tab, then recurse
  on each side. Then replay the moves one pane at a time. Estimated at
  100-150 lines of Lua that call `wezterm cli` through
  `wezterm.run_child_process`, since Lua's `pane:split` doesn't appear to
  take an existing pane. Expect split sizes to land a cell or so
  off and the panes to visibly reshuffle while it runs.

- **Mark tabs, move to a window:** easy once the piece above exists. Keep
  the marks in `wezterm.GLOBAL` and show them with the `format-tab-title`
  event. To move a tab, send its first pane with
  `move-pane-to-new-tab --window-id`, then rebuild the rest of the layout
  the same way.
- **Named windows across relaunch:** `set_title` is built in. To restore
  names after relaunch, use a resurrect fork or write the names to a file
  from Lua. A separate mux server (`unix_domains`) may keep panes alive
  through quitting the app, though not a reboot. That's from memory and
  wasn't checked.
- **`move_split`:** half of it. The move itself can be scripted with a key
  table: arrows pick a neighbor and a side, then
  `split-pane --move-pane-id` does the move. The live half-split highlight
  can't be built, because Lua apparently can't draw over panes. The best
  substitute is showing the target in the status bar.
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

## Fuzzy tab switcher across windows

Recon against `/Users/chrismo/dev/wezterm` at `e2a98e1b8`.

**Yes, without forking WezTerm.** A current-window fuzzy tab picker is built in;
an all-window version can be written in the Lua config using the built-in
`InputSelector`. No plugin or external `fzf` process is required. The same Lua
could be packaged as a plugin if useful.

### Built-in: tabs in the current window

Add this entry to `config.keys`:

```lua
{
  key = 'p',
  mods = 'CMD',
  action = wezterm.action.ShowLauncherArgs { flags = 'FUZZY|TABS' },
},
```

This starts directly in fuzzy mode and lists one entry per tab, not per pane.
It uses the explicit tab title, falling back to the active pane's title, and
may append a pane count. **`TABS` only covers the current window**; there is no
all-windows launcher flag in this checkout.

### Scriptable: tabs across GUI windows in the active workspace

This is a candidate `wezterm.lua`, not an installed or GUI-tested configuration.
Lua syntax and mocked enumeration, cancellation, closed-tab, and activation checks
pass. Matching and actual macOS window focus still need an in-app check.
Merge its binding into an existing config rather than replacing unrelated settings.

```lua
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.keys = {
  {
    key = 'p',
    mods = 'CMD',
    action = wezterm.action_callback(function(window, pane)
      local choices = {}
      for _, mux_window in ipairs(wezterm.mux.all_windows()) do
        if mux_window:gui_window() then
          local window_title = mux_window:get_title()
          if window_title == '' then
            window_title = 'Window ' .. mux_window:window_id()
          end
          for _, info in ipairs(mux_window:tabs_with_info()) do
            local tab = info.tab
            local active = tab:active_pane()
            local title = tab:get_title()
            if title == '' then
              title = active and active:get_title() or 'Untitled'
            end
            local cwd = active and active:get_current_working_dir()
            local label = string.format(
              '%s — %d: %s', window_title, info.index + 1, title
            )
            if cwd then
              label = label .. '  ' .. (cwd.file_path or tostring(cwd))
            end
            table.insert(choices, { id = tostring(tab:tab_id()), label = label })
          end
        end
      end

      window:perform_action(act.InputSelector {
        title = 'Switch to a tab',
        fuzzy = true,
        choices = choices,
        action = wezterm.action_callback(function(_, _, id)
          if not id then return end
          local tab = wezterm.mux.get_tab(tonumber(id))
          if not tab then return end
          local target = tab:window():gui_window()
          if not target then return end
          tab:activate()
          target:focus()
        end),
      }, pane)
    end),
  },
}

return config
```

Properties relevant to the desired Moestty switcher:

- One row per tab, regardless of how many panes it contains.
- Searches the combined window title, tab title, and active pane's working
  directory when known. Emoji prefixes do not have to be typed.
- Activates the tab without choosing a different pane inside it; focuses its
  containing GUI window. Window focusing is supported on macOS.
- Escape cancels; Enter accepts; arrows and Ctrl-N/P navigate.
- Uses stable tab IDs and resolves the destination again on selection, so a
  tab closed while the picker is open is ignored.
- This example only includes mux windows with a corresponding GUI window:
  normally the active workspace. Other workspaces need explicit workspace
  switching before resolving/focusing their GUI windows; detached mux windows
  also need separate handling. It is not an all-workspaces/session switcher.
- List order is the enumeration order, not an MRU policy. The selector snapshots
  the choices on opening; titles and membership do not update while it is open.

### Matching: genuinely fuzzy, with a version caveat

Both the launcher and InputSelector in this checkout use `nucleo-matcher` 0.3:
`Pattern::parse` with case-insensitive matching and smart normalization, then
rank candidates by score. This is not Ghostty's contiguous-substring/word-initial
matcher. Nucleo supports whitespace-separated query atoms and gaps within fuzzy
terms, rather than requiring a phrase like `Focus ghostty` to appear verbatim.
It still matches character order within a term; it is not arbitrary permutation
or typo correction, nor a promise of identical behavior to every `fzf` option.

The switch to nucleo is listed under **Continuous/Nightly** in WezTerm's
changelog. Do not assume an older stable binary has the same matcher as this
clone. The Lua primitives used above are documented as available by the
20240127 release.

### Comparison with this Ghostty/Moestty checkout

| Requirement | Ghostty/Moestty today | WezTerm |
| --- | --- | --- |
| Real fuzzy filtering | No; substring or word initials | Built-in; nucleo in this checkout |
| Tabs only, not individual panes | Existing Focus entries enumerate panes | Launcher is tab-based; Lua can enumerate tabs |
| Across windows | Existing Focus entries already do this | Lua config using mux enumeration + InputSelector |
| Include named windows in search | Window menu does; Focus entries don't | Compose window/tab labels in Lua |
| Customization without maintaining a fork | No comparable Lua picker API here | Supported config callbacks; optional plugin packaging |

For this feature alone, WezTerm already provides the customization surface we
would otherwise add to Moestty. No third-party plugin was evaluated in this pass.

### Source references

Paths relative to `/Users/chrismo/dev/wezterm`:

- `docs/config/lua/keyassignment/ShowLauncherArgs.md`
- `docs/config/lua/keyassignment/InputSelector.md`
- `docs/config/lua/wezterm.mux/all_windows.md`
- `docs/config/lua/mux-window/{tabs_with_info,gui_window,get_title}.md`
- `docs/config/lua/MuxTab/{activate,active_pane,get_title,window}.md`
- `docs/config/lua/window/focus.md`
- `docs/config/plugins.md`
- `wezterm-gui/src/overlay/launcher.rs`: current-window tab enumeration.
- `wezterm-gui/src/overlay/selector.rs`: nucleo parsing, scoring, and ordering.
- `lua-api-crates/mux/src/tab.rs`: activation preserves the tab's active pane.
- `docs/changelog.md`: nucleo change under Continuous/Nightly.
