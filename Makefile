# Sizely – Cinnamon-Extension
#
# Ziel-Host: Linux Mint / Cinnamon (X11). Windows wird nicht unterstützt,
# siehe Makefile.bat.

UUID        := sizely@gossardla
SRCDIR      := src/$(UUID)
XLETDIR     := $(HOME)/.local/share/cinnamon/extensions
DESTDIR     := $(XLETDIR)/$(UUID)
CONFIGDIR   := $(HOME)/.config/cinnamon/spices/$(UUID)
LOCALEDIR   := $(HOME)/.local/share/locale
POTFILE     := po/$(UUID).pot
POFILES     := $(wildcard po/*.po)
BUILDDIR    := build
ZIP         := $(BUILDDIR)/$(UUID).zip
JS_SOURCES  := $(wildcard $(SRCDIR)/*.js) $(wildcard tools/*.js)

DBUS_SEND   := dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon

.PHONY: all help install uninstall reinstall enable disable reload restart \
        logs lint check clean distclean deploy dist status pot install-locale \
        uninstall-locale i18n-check

all: help

help:
	@echo "Sizely – verfügbare Targets:"
	@echo "  make install     Extension installieren und aktivieren"
	@echo "  make uninstall   Extension deaktivieren und entfernen"
	@echo "  make reinstall   uninstall + install"
	@echo "  make reload      Extension im laufenden Cinnamon neu laden"
	@echo "  make restart     Cinnamon neu starten"
	@echo "  make enable      Nur aktivieren (bereits installiert)"
	@echo "  make disable     Nur deaktivieren"
	@echo "  make status      Installations- und Aktivierungsstatus anzeigen"
	@echo "  make logs        Cinnamon-Log auf diese Extension gefiltert verfolgen"
	@echo "  make lint        JS-Syntax und JSON-Schema prüfen"
	@echo "  make pot         Übersetzungsvorlage po/$(UUID).pot neu erzeugen"
	@echo "  make i18n-check  Übersetzungen gegen die Vorlage abgleichen"
	@echo "  make dist        ZIP für den Cinnamon-Spices-Upload bauen"
	@echo "  make clean       Build-Artefakte entfernen"
	@echo "  make distclean   clean + gespeicherte Einstellungen entfernen"

# ---------------------------------------------------------------------------
# Prüfungen
# ---------------------------------------------------------------------------

lint:
	@command -v cjs >/dev/null || { echo "cjs (Cinnamon-JS) nicht gefunden"; exit 1; }
	@cjs tools/syntaxcheck.js $(JS_SOURCES)
	@for po in $(POFILES); do msgfmt --check -o /dev/null $$po && echo "OK      $$po"; done
	@python3 -c "import json,sys; json.load(open('$(SRCDIR)/settings-schema.json')); print('OK      $(SRCDIR)/settings-schema.json')"
	@python3 -c "import json,sys; json.load(open('$(SRCDIR)/metadata.json')); print('OK      $(SRCDIR)/metadata.json')"

check: lint

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

install: lint install-locale
	@mkdir -p $(XLETDIR)
	@rm -rf $(DESTDIR)
	@cp -a $(SRCDIR) $(DESTDIR)
	@echo "Installiert nach $(DESTDIR)"
	@$(MAKE) --no-print-directory enable

uninstall: disable uninstall-locale
	@rm -rf $(DESTDIR)
	@echo "Entfernt: $(DESTDIR)"

# ---------------------------------------------------------------------------
# Übersetzungen
# ---------------------------------------------------------------------------

# Quellsprache ist Englisch; die msgids stammen aus extension.js und
# settings-schema.json. cinnamon-json-makepot wird bewusst nicht benutzt, es
# setzt python3-polib voraus.
pot:
	@python3 tools/makepot.py $(SRCDIR) $(POTFILE)

# Cinnamon erwartet die Kataloge unter ~/.local/share/locale, benannt nach der
# UUID (siehe appletManager.js:617).
install-locale:
	@for po in $(POFILES); do \
		lang=$$(basename $$po .po); \
		mkdir -p $(LOCALEDIR)/$$lang/LC_MESSAGES; \
		msgfmt -o $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo $$po || exit 1; \
		echo "Übersetzung installiert: $$lang"; \
	done

uninstall-locale:
	@for po in $(POFILES); do \
		lang=$$(basename $$po .po); \
		rm -f $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo; \
	done
	@echo "Übersetzungen entfernt."

i18n-check: pot
	@for po in $(POFILES); do \
		printf "%s: " $$po; \
		msgcmp $$po $(POTFILE) 2>&1 && echo "vollständig"; \
	done

reinstall: uninstall install

# Fügt die UUID zu org.cinnamon enabled-extensions hinzu, ohne die bestehende
# Liste zu überschreiben.
enable:
	@python3 -c "$$ENABLE_SCRIPT" add $(UUID)

disable:
	@python3 -c "$$ENABLE_SCRIPT" remove $(UUID)

status:
	@echo "Quelle:      $(SRCDIR)"
	@if [ -d $(DESTDIR) ]; then echo "Installiert: ja  ($(DESTDIR))"; else echo "Installiert: nein"; fi
	@printf "Aktiviert:   "; \
	 gsettings get org.cinnamon enabled-extensions | grep -q "$(UUID)" && echo "ja" || echo "nein"
	@printf "Einstellungen: "; \
	 if [ -d $(CONFIGDIR) ]; then echo "$(CONFIGDIR)"; else echo "(noch keine)"; fi

# ---------------------------------------------------------------------------
# Laufzeit
# ---------------------------------------------------------------------------

reload:
	@$(DBUS_SEND) org.Cinnamon.ReloadXlet string:'$(UUID)' string:'EXTENSION' >/dev/null
	@echo "Extension neu geladen."

restart:
	@$(DBUS_SEND) org.Cinnamon.RestartCinnamon boolean:true >/dev/null
	@echo "Cinnamon wird neu gestartet."

logs:
	@echo "Verfolge ~/.xsession-errors (Filter: $(UUID)) – Abbruch mit Strg+C"
	@tail -n 50 -f $(HOME)/.xsession-errors | grep --line-buffered -E '$(UUID)|Cinnamon Error|JS ERROR'

# ---------------------------------------------------------------------------
# Verteilung
# ---------------------------------------------------------------------------

dist: lint
	@mkdir -p $(BUILDDIR)
	@rm -f $(ZIP)
	@cd src && zip -qr ../$(ZIP) $(UUID)
	@zip -qr $(ZIP) po
	@echo "Paket gebaut: $(ZIP)"

# Es gibt keinen Webserver-Deploy für eine lokale Desktop-Extension. Das
# Äquivalent ist das Spices-Paket – deshalb zeigt deploy darauf.
deploy: dist
	@echo
	@echo "Hinweis: Diese Extension läuft lokal, es gibt kein Deploy-Ziel."
	@echo "Das Paket für einen Upload auf cinnamon-spices liegt unter $(ZIP)."
	@echo "Für die Installation auf diesem Host: make install"

# ---------------------------------------------------------------------------

clean:
	@rm -rf $(BUILDDIR)
	@echo "Build-Artefakte entfernt."

distclean: clean
	@rm -rf $(CONFIGDIR)
	@echo "Gespeicherte Einstellungen entfernt: $(CONFIGDIR)"

# ---------------------------------------------------------------------------

define ENABLE_SCRIPT
import subprocess, sys, ast
action, uuid = sys.argv[1], sys.argv[2]
key = ["gsettings", "get", "org.cinnamon", "enabled-extensions"]
raw = subprocess.check_output(key, text=True).strip()
current = [] if raw in ("@as []", "[]") else ast.literal_eval(raw)
if action == "add":
    if uuid in current:
        print("Bereits aktiviert: %s" % uuid); sys.exit(0)
    current.append(uuid)
else:
    if uuid not in current:
        print("Nicht aktiviert: %s" % uuid); sys.exit(0)
    current.remove(uuid)
value = "[" + ", ".join("'%s'" % u for u in current) + "]"
subprocess.check_call(["gsettings", "set", "org.cinnamon", "enabled-extensions", value])
print(("Aktiviert: %s" if action == "add" else "Deaktiviert: %s") % uuid)
endef
export ENABLE_SCRIPT
