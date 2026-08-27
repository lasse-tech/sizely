# Sizely

A Cinnamon extension that resizes windows to configurable sizes and centers them
on the current monitor — from the title bar context menu or by keyboard shortcut.

## Features

* **Your own presets** — any number of them, each with a name, width, height and
  an optional "center" flag. They appear in the window menu, either grouped in a
  "Size" submenu or listed directly.
* **Standard resolutions** — a built-in list of common display resolutions,
  grouped by aspect ratio. See below.
* **Center on monitor** — places the window in the middle of the monitor it
  currently sits on, without changing its size.
* **Keyboard shortcuts** — for centering and for the first five preset rows.
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
| 4:3 / 5:4 | SVGA, XGA, XGA+, SXGA, SXGA+, UXGA, QXGA, QUXGA |
| 21:9 | UWFHD, UWQHD, UW4K, UW5K |
| 32:9 | DQHD, DUHD (off by default) |
| Digital Cinema | DCI 2K, DCI 4K (off by default) |

The values are taken from
[Display resolution standards](https://en.wikipedia.org/wiki/Display_resolution_standards)
and live in `src/sizely@gossardla/resolutions.js`.

Two notes:

* These resolutions are **always exact physical pixels**. Picking "1920 × 1080"
  should give you a window with exactly that pixel count, so the *unit* setting
  below applies to your own presets only.
* By default only resolutions that **fit the current monitor** are listed; larger
  ones would just be clamped to the work area anyway. On a 5120 × 2880 screen
  with a panel, "5K" is correctly absent because the work area is only 2800 px
  tall. This can be turned off.

Each group can be shown or hidden individually.

## HiDPI: logical vs. physical pixels

On X11 Muffin works in **physical** pixels; the UI scaling factor
(`global.ui_scale`) is not applied. On a HiDPI display with scaling factor 2, a
preset of "1920 × 1200" would therefore look half the expected size.

Hence the **unit for preset sizes** setting:

| Setting | Meaning |
|---|---|
| Logical pixels (default) | The size is multiplied by `ui_scale`. At scaling factor 2, 1280 × 800 becomes 2560 × 1600 real pixels — what you visually expect. |
| Physical pixels | The value is used as-is. |

Presets larger than the monitor's work area are clamped to it.

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

The preset shortcuts are separate settings (`preset-1-keybinding` …
`preset-5-keybinding`) rather than a column inside the table. The reason is a bug
in Cinnamon: `TreeListWidgets.list_edit_factory()` builds the widget for a
`keybinding` column without a settings backend, so its constructor trips over
`self.backend` in `SettingsWidgets.py:482` and the list's edit dialog crashes
with `AttributeError: 'Widget' object has no attribute 'backend'`. This affects
every xlet, including Cinnamon's own `settings-example@cinnamon.org`.

## Requirements

Cinnamon 6.0 – 6.6 on X11. Tested on Linux Mint 22.3 "Zena" with Cinnamon 6.6.9.

## License

MIT — see [LICENSE](LICENSE).
