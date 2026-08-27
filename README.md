# Sizely

A Cinnamon extension that resizes windows to configurable sizes and centers them
on the current monitor — from the title bar context menu or by keyboard shortcut.

## Features

* **Your own presets** — any number of them, each with a name, width, height, an
  optional "center" flag and an optional keyboard shortcut. They appear in the
  window menu, either grouped in a "Size" submenu or listed directly.
* **Standard resolutions** — a built-in list of common display resolutions,
  grouped by aspect ratio. See below.
* **Center on monitor** — places the window in the middle of the monitor it
  currently sits on, without changing its size.
* **Keyboard shortcuts** — for centering and for every preset row.
* Everything is configurable through the Cinnamon extension settings.

## Why not wmctrl or xdotool

Sizely works purely through the Muffin API (`get_work_area_current_monitor()` and
`move_resize_frame()`). That makes three things correct:

* the **panel offset** — and only on the monitor the panel actually lives on,
* the **monitor boundaries** on multi-monitor setups with different resolutions,
* the **frame geometry**, title bar included.

`wmctrl` and `xdotool` compute against the virtual combined screen and know
nothing about individual monitors — centering would drop a window right on the
seam between two displays.

## Standard resolutions

The **Standard resolutions** submenu contains the common display standards,
grouped by aspect ratio:

| Group | Examples |
|---|---|
| 16:9 | qHD, HD 720p, HD+, FHD 1080p, QHD 1440p, 3K, QHD+, 4K UHD, 5K, 8K UHD |
| 16:10 | WXGA, WXGA+, WSXGA+, WUXGA, WQXGA, WQXGA+, WQUXGA |
| 4:3 / 5:4 | SVGA, XGA, XGA+, SXGA, SXGA+, UXGA, QXGA, QUXGA (off by default) |
| 21:9 | UWFHD, UWQHD, UW4K, UW5K (off by default) |
| 32:9 | DQHD, DUHD (off by default) |
| Digital Cinema | DCI 2K, DCI 4K (off by default) |

The values are taken from
[Display resolution standards](https://en.wikipedia.org/wiki/Display_resolution_standards)
and live in `src/sizely@gossardla/resolutions.js`.

By default only resolutions that **fit the current monitor** are listed; larger
ones would just be clamped to the work area anyway. The check uses the scaled
size, so the list adapts to the monitor the window is on. Each group can be shown
or hidden individually.

## HiDPI: logical vs. physical pixels

On X11 Muffin moves and resizes windows in **physical** pixels — the UI scaling
factor is not applied for you. Sizely reads it from `global.ui_scale` (falling
back to `St.ThemeContext.scale_factor`).

Do **not** use `Meta.Display.get_monitor_scale()` for this. It returns the
per-monitor fractional-scaling factor from the display configuration, not the UI
scaling factor Cinnamon actually renders with. On the test machine it reports
1.0 and 1.5 for the two monitors while the real UI factor is 2 on both —
verifiable through the panel, which is configured to 40 px and measures 80 px.

Hence the **unit for all sizes** setting:

| Setting | Meaning |
|---|---|
| Logical pixels (default) | The size is multiplied by the UI scaling factor. At factor 2, "1920 × 1080" becomes 3840 × 2160 real pixels and covers the same area a Full HD screen would. |
| Physical pixels | The value is used as-is, ignoring scaling. |

This applies to your own presets and to the standard resolutions alike. Sizes
larger than the monitor's work area are clamped to it, and the fit filter uses
the scaled size — which is why a 3840 × 2160 monitor at factor 2 lists 16:9 only
up to 1920 × 1080.

## Installation

```bash
make install     # install, compile translations and enable
make reload      # reload in the running Cinnamon after code changes
make uninstall   # disable and remove everything again
```

Configure it with

```bash
xlet-settings extension sizely@gossardla
```

or through *Settings → Extensions → Sizely → gear icon*. The default shortcut for
centering is <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>; presets ship without
a shortcut.

Run `make help` for all targets.

## Translations

English is the source language, `po/de.po` holds the German translation. The
mnemonics (`_` in menu labels) are chosen so they do not collide with the
standard entries of the Cinnamon window menu.

```bash
make pot          # regenerate po/sizely@gossardla.pot
make i18n-check   # compare translations against the template
```

To add a language: `msginit -i po/sizely@gossardla.pot -l xx -o po/xx.po`,
translate it, then `make install`. Catalogs are installed to
`~/.local/share/locale/<lang>/LC_MESSAGES/sizely@gossardla.mo`.

> **Note:** A translation only takes effect when the session runs in that
> language (`LANG`). With `LANG=en_US.UTF-8` both Sizely and the stock Cinnamon
> entries in the window menu appear in English.

## Submitting to cinnamon-spices

```bash
make screenshot   # capture screenshot.png from the running window menu
make spice        # build the required layout in build/spice/
make validate     # run the official validate-spice script against it
```

`make spice` produces the layout the
[cinnamon-spices-extensions](https://github.com/linuxmint/cinnamon-spices-extensions)
repository expects (`UUID/info.json`, `UUID/screenshot.png`,
`UUID/files/UUID/...` with `po/` inside). Copy `build/spice/sizely@gossardla`
into a fork of that repository and open a pull request.

## How it works

The extension patches `WindowMenu.prototype._buildMenu` from
`/usr/share/cinnamon/js/ui/windowMenu.js`. Cinnamon builds a fresh menu instance
on every right-click (`windowManager.js:399`), so the patch takes effect
immediately and without a restart. No system files are modified, and `disable()`
restores the original.

Entries are inserted before the trailing separator so that "Close" stays last.

Keyboard shortcuts go through `Main.keybindingManager` and are rebound whenever
the settings change.

### Known issue: editing presets in the settings dialog

The preset shortcuts live in a `keybinding` column of the presets table. That
column type is broken in Cinnamon: `TreeListWidgets.list_edit_factory()` builds
the widget without a settings backend, so `Keybinding.__init__` trips over
`self.backend` (`SettingsWidgets.py:482`). Both the **Add** and the **Edit**
button of the table therefore fail with

```
AttributeError: 'Widget' object has no attribute 'backend'
```

This affects every xlet using a `keybinding` column, including Cinnamon's own
`settings-example@cinnamon.org` — it is not specific to Sizely.

Until it is fixed upstream, edit the presets directly in

```
~/.config/cinnamon/spices/sizely@gossardla/sizely@gossardla.json
```

and tell Cinnamon to reload them:

```bash
gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon \
  --method org.Cinnamon.updateSetting sizely@gossardla sizely@gossardla presets ""
```

Everything else in the settings dialog works normally.

## Requirements

Cinnamon 6.0 – 6.6 on X11. Tested on Linux Mint 22.3 "Zena" with Cinnamon 6.6.9.

## License

MIT — see [LICENSE](LICENSE).
