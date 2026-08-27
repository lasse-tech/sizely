# Sizely

Cinnamon-Extension, die Fenster auf konfigurierbare Größen bringt und auf dem
aktuellen Monitor zentriert – per Rechtsklick auf die Titelleiste oder per
Tastenkombination.

![Fenstermenü](#) <!-- Screenshot bei Bedarf ergänzen -->

## Funktion

* **Eigene Größen-Presets** – beliebig viele, jeweils mit Name, Breite, Höhe und
  optionalem „Zentrieren“. Erscheinen im Fenstermenü, wahlweise als Untermenü
  „Größe festlegen“ oder direkt.
* **Standardauflösungen** – eine eingebaute Liste gängiger Bildschirmauflösungen
  (VGA bis 8K), nach Seitenverhältnis gruppiert. Siehe unten.
* **Auf Monitor zentrieren** – setzt das Fenster mittig auf den Monitor, auf dem
  es gerade liegt, ohne die Größe zu ändern.
* **Tastenkombinationen** – für das Zentrieren und für die ersten fünf
  Preset-Zeilen.
* Alles über die Cinnamon-Extension-Einstellungen konfigurierbar.

## Warum keine wmctrl/xdotool-Lösung

Sizely rechnet ausschließlich über die Muffin-API
(`get_work_area_current_monitor()` und `move_resize_frame()`). Damit stimmen

* der **Panel-Abzug** – und zwar nur auf dem Monitor, auf dem das Panel liegt,
* die **Monitorgrenzen** bei mehreren Bildschirmen mit unterschiedlichen
  Auflösungen,
* die **Frame-Geometrie** inklusive Titelleiste.

`wmctrl` und `xdotool` rechnen dagegen gegen den virtuellen Gesamtscreen und
kennen die einzelnen Monitore nicht – Zentrieren würde ein Fenster auf der
Grenze zwischen zwei Bildschirmen absetzen.

## Standardauflösungen

Das Untermenü **Standardauflösungen** enthält die gängigen Anzeigestandards,
gruppiert nach Seitenverhältnis:

| Gruppe | Beispiele |
|---|---|
| 16:9 | qHD, HD 720p, HD+, FHD 1080p, QHD 1440p, 3K, QHD+, 4K UHD, 5K, 8K UHD |
| 16:10 | WXGA, WXGA+, WSXGA+, WUXGA, WQXGA, WQXGA+, WQUXGA |
| 4:3 / 5:4 | SVGA, XGA, XGA+, SXGA, SXGA+, UXGA, QXGA, QUXGA |
| 21:9 | UWFHD, UWQHD, UW4K, UW5K |
| 32:9 | DQHD, DUHD (ab Werk aus) |
| Digital Cinema | DCI 2K, DCI 4K (ab Werk aus) |

Die Werte stammen aus
[Display resolution standards](https://en.wikipedia.org/wiki/Display_resolution_standards)
und stehen in `src/sizely@gossardla/resolutions.js`.

Zwei Punkte dazu:

* Diese Auflösungen sind **immer exakte physische Pixel**. Wer „1920 × 1080“
  wählt, will ein Fenster mit genau dieser Pixelzahl – die Einstellung *Einheit
  der Preset-Größen* gilt deshalb nur für die eigenen Presets.
* Standardmäßig werden nur Auflösungen gezeigt, die auf den **aktuellen Monitor**
  passen; größere würden ohnehin nur auf den Arbeitsbereich begrenzt. Auf einem
  5120 × 2880-Schirm mit Panel fehlt „5K“ also korrekterweise, weil die Workarea
  nur 2800 px hoch ist. Abschaltbar über *Only list resolutions that fit*.

Jede Gruppe lässt sich einzeln ein- und ausblenden.

## HiDPI: logische vs. physische Pixel

Muffin arbeitet unter X11 in **physischen** Pixeln; der UI-Skalierungsfaktor
(`global.ui_scale`) wird nicht eingerechnet. Auf einem HiDPI-Display mit
Skalierung 2 wäre ein Preset „1920 × 1200“ optisch nur halb so groß wie
erwartet.

Deshalb gibt es die Einstellung **Einheit der Preset-Größen**:

| Einstellung | Bedeutung |
|---|---|
| Logische Pixel (Standard) | Die Größe wird mit `ui_scale` multipliziert. 1280 × 800 ergibt bei Skalierung 2 also 2560 × 1600 echte Pixel – das, was optisch erwartet wird. |
| Physische Pixel | Der Wert wird unverändert übernommen. |

Presets, die größer sind als der Arbeitsbereich des Monitors, werden auf dessen
Größe begrenzt.

## Installation

```bash
make install     # installiert, übersetzt und aktiviert
make reload      # nach Codeänderungen im laufenden Cinnamon neu laden
make uninstall   # deaktiviert und entfernt alles wieder
```

Konfiguriert wird über

```bash
xlet-settings extension sizely@gossardla
```

oder *Einstellungen → Erweiterungen → Sizely → Zahnrad*. Voreingestellt ist
<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> für das Zentrieren; die Presets
haben ab Werk keine Tastenkombination.

`make help` listet alle Targets.

## Übersetzungen

Quellsprache ist Englisch, `po/de.po` enthält die deutsche Übersetzung. Die
Mnemonics (`_` im Menütext) sind so gewählt, dass sie nicht mit den
Standardeinträgen des Cinnamon-Fenstermenüs kollidieren.

```bash
make pot          # Vorlage po/sizely@gossardla.pot neu erzeugen
make i18n-check   # Übersetzungen gegen die Vorlage abgleichen
```

Neue Sprache: `msginit -i po/sizely@gossardla.pot -l xx -o po/xx.po`, übersetzen,
`make install`. Die Kataloge landen unter
`~/.local/share/locale/<sprache>/LC_MESSAGES/sizely@gossardla.mo`.

> **Hinweis:** Die Übersetzung greift nur, wenn die Sitzung in der jeweiligen
> Sprache läuft (`LANG`). Bei `LANG=en_US.UTF-8` erscheinen sowohl Sizely als
> auch die Cinnamon-Einträge im Fenstermenü auf Englisch.

## Technischer Hintergrund

Die Extension patcht `WindowMenu.prototype._buildMenu` aus
`/usr/share/cinnamon/js/ui/windowMenu.js`. Cinnamon erzeugt bei jedem Rechtsklick
eine neue Menü-Instanz (`windowManager.js:399`), der Patch greift also sofort und
ohne Neustart. Systemdateien werden nicht verändert; `disable()` stellt den
Originalzustand wieder her.

Die Einträge werden vor dem abschließenden Separator eingehängt, damit
„Schließen“ der letzte Eintrag bleibt.

Tastenkombinationen laufen über `Main.keybindingManager` und werden bei jeder
Einstellungsänderung neu gebunden.

Die Preset-Hotkeys liegen als eigene Einstellungen (`preset-1-keybinding` …
`preset-5-keybinding`) neben der Tabelle, nicht als Spalte darin. Grund ist ein
Fehler in Cinnamon: `TreeListWidgets.list_edit_factory()` erzeugt das Widget für
eine `keybinding`-Spalte ohne Settings-Backend, worauf dessen Konstruktor in
`SettingsWidgets.py:482` über `self.backend` stolpert – der Bearbeiten-Dialog der
Liste stürzt dann mit `AttributeError: 'Widget' object has no attribute
'backend'` ab. Das betrifft jedes Xlet, auch Cinnamons eigenes
`settings-example@cinnamon.org`.

## Voraussetzungen

Cinnamon 6.0 – 6.6 unter X11. Getestet auf Linux Mint 22.3 „Zena“ mit
Cinnamon 6.6.9.

## Lizenz

MIT – siehe [LICENSE](LICENSE).
