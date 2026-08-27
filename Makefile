UUID        := sizely@gossardla
APPLET_UUID := sizely-applet@gossardla
SRCDIR      := src/$(UUID)
APPLET_SRC  := src/$(APPLET_UUID)
SHAREDDIR   := src/shared
XLETDIR     := $(HOME)/.local/share/cinnamon/extensions
APPLETDIR   := $(HOME)/.local/share/cinnamon/applets
DESTDIR     := $(XLETDIR)/$(UUID)
APPLET_DEST := $(APPLETDIR)/$(APPLET_UUID)
CONFIGDIR   := $(HOME)/.config/cinnamon/spices/$(UUID)
# Honour XDG_DATA_HOME; falls back to the spec default when it is unset.
LOCALEDIR   := $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)/locale
POTFILE     := po/$(UUID).pot
POFILES     := $(wildcard po/*.po)
APPLET_POT  := po-applet/$(APPLET_UUID).pot
APPLET_POS  := $(wildcard po-applet/*.po)
BUILDDIR    := build
SPICEDIR    := $(BUILDDIR)/spice/$(UUID)
ZIP         := $(BUILDDIR)/$(UUID).zip
JS_SOURCES  := $(wildcard $(SRCDIR)/*.js) $(wildcard $(APPLET_SRC)/*.js) \
               $(wildcard $(SHAREDDIR)/*.js) $(wildcard tools/*.js)

DBUS_SEND   := dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon

.PHONY: all help install uninstall reinstall enable disable reload restart \
        logs lint check clean distclean spices-package dist status pot install-locale \
        uninstall-locale i18n-check icon screenshot spice spice-shot validate

all: help

help:
	@echo "Sizely - available targets:"
	@echo "  make install     install, compile translations and enable"
	@echo "  make uninstall   disable and remove everything"
	@echo "  make reinstall   uninstall + install"
	@echo "  make reload      reload the extension in the running Cinnamon"
	@echo "  make restart     restart Cinnamon"
	@echo "  make enable      enable only (already installed)"
	@echo "  make disable     disable only"
	@echo "  make status      show installation and activation state"
	@echo "  make logs        follow the Cinnamon log, filtered to this extension"
	@echo "  make lint        check JS syntax, JSON schema and translations"
	@echo "  make pot         regenerate $(POTFILE)"
	@echo "  make i18n-check  compare translations against the template"
	@echo "  make icon        regenerate $(SRCDIR)/icon.png"
	@echo "  make screenshot  capture screenshot.png from the running menu"
	@echo "  make spice       build the cinnamon-spices layout in $(SPICEDIR)"
	@echo "  make spice-shot  rebuild spice/screenshot.png from the two captures"
	@echo "  make validate    run the official validate-spice against that layout"
	@echo "  make dist        build a zip archive"
	@echo "  make clean       remove build artefacts"
	@echo "  make distclean   clean + remove stored settings"

lint:
	@command -v cjs >/dev/null || { echo "cjs (Cinnamon JS) not found"; exit 1; }
	@cjs tools/syntaxcheck.js $(JS_SOURCES)
	@for po in $(POFILES) $(APPLET_POS); do msgfmt --check -o /dev/null $$po && echo "OK      $$po"; done
	@python3 -c "import json; json.load(open('$(SRCDIR)/settings-schema.json')); print('OK      $(SRCDIR)/settings-schema.json')"
	@python3 -c "import json; json.load(open('$(SRCDIR)/metadata.json')); print('OK      $(SRCDIR)/metadata.json')"
	@python3 -c "import json; json.load(open('$(APPLET_SRC)/settings-schema.json')); print('OK      $(APPLET_SRC)/settings-schema.json')"
	@python3 -c "import json; json.load(open('$(APPLET_SRC)/metadata.json')); print('OK      $(APPLET_SRC)/metadata.json')"

check: lint

install: lint install-locale
	@mkdir -p $(XLETDIR) $(APPLETDIR)
	@rm -rf $(DESTDIR) $(APPLET_DEST)
	@cp -a $(SRCDIR) $(DESTDIR)
	@cp -a $(APPLET_SRC) $(APPLET_DEST)
	@cp $(SHAREDDIR)/*.js $(DESTDIR)/
	@cp $(SHAREDDIR)/*.js $(APPLET_DEST)/
	@echo "Installed to $(DESTDIR)"
	@echo "Installed to $(APPLET_DEST)"
	@$(MAKE) --no-print-directory enable

uninstall: disable uninstall-locale
	@rm -rf $(DESTDIR) $(APPLET_DEST)
	@echo "Removed: $(DESTDIR)"
	@echo "Removed: $(APPLET_DEST)"

reinstall: uninstall install

pot:
	@python3 tools/makepot.py $(SRCDIR) $(SHAREDDIR) $(POTFILE)
	@python3 tools/makepot.py $(APPLET_SRC) $(SHAREDDIR) $(APPLET_POT)

install-locale:
	@for po in $(POFILES); do \
		lang=$$(basename $$po .po); \
		mkdir -p $(LOCALEDIR)/$$lang/LC_MESSAGES; \
		msgfmt -o $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo $$po || exit 1; \
		echo "Translation installed: $(UUID) $$lang"; \
	done
	@for po in $(APPLET_POS); do \
		lang=$$(basename $$po .po); \
		mkdir -p $(LOCALEDIR)/$$lang/LC_MESSAGES; \
		msgfmt -o $(LOCALEDIR)/$$lang/LC_MESSAGES/$(APPLET_UUID).mo $$po || exit 1; \
		echo "Translation installed: $(APPLET_UUID) $$lang"; \
	done

uninstall-locale:
	@for po in $(POFILES) $(APPLET_POS); do \
		lang=$$(basename $$po .po); \
		rm -f $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo; \
		rm -f $(LOCALEDIR)/$$lang/LC_MESSAGES/$(APPLET_UUID).mo; \
	done
	@echo "Translations removed."

i18n-check: pot
	@for po in $(POFILES); do \
		printf "%s: " $$po; \
		msgcmp $$po $(POTFILE) 2>&1 && echo "complete"; \
	done
	@for po in $(APPLET_POS); do \
		printf "%s: " $$po; \
		msgcmp $$po $(APPLET_POT) 2>&1 && echo "complete"; \
	done

enable:
	@python3 -c "$$ENABLE_SCRIPT" add $(UUID)

disable:
	@python3 -c "$$ENABLE_SCRIPT" remove $(UUID)

status:
	@echo "Source:       $(SRCDIR)"
	@if [ -d $(DESTDIR) ]; then echo "Installed:    yes  ($(DESTDIR))"; else echo "Installed:    no"; fi
	@printf "Enabled:      "; \
	 gsettings get org.cinnamon enabled-extensions | grep -q "$(UUID)" && echo "yes" || echo "no"
	@printf "Settings:     "; \
	 if [ -d $(CONFIGDIR) ]; then echo "$(CONFIGDIR)"; else echo "(none yet)"; fi

reload:
	@$(DBUS_SEND) org.Cinnamon.ReloadXlet string:'$(UUID)' string:'EXTENSION' >/dev/null
	@$(DBUS_SEND) org.Cinnamon.ReloadXlet string:'$(APPLET_UUID)' string:'APPLET' >/dev/null 2>&1 || true
	@echo "Extension and applet reloaded."

restart:
	@$(DBUS_SEND) org.Cinnamon.RestartCinnamon boolean:true >/dev/null
	@echo "Restarting Cinnamon."

logs:
	@echo "Following ~/.xsession-errors (filter: $(UUID)) - stop with Ctrl+C"
	@tail -n 50 -f $(HOME)/.xsession-errors | grep --line-buffered -E '$(UUID)|Cinnamon Error|JS ERROR'

icon:
	@python3 tools/make_icon.py $(SRCDIR)/icon.png

screenshot:
	@python3 tools/make_screenshot.py screenshot.png

spice-shot:
	@test -n "$(MENU)" -a -n "$(SETTINGS)" || { \
	 echo "usage: make spice-shot MENU=menu.png SETTINGS=settings.png"; exit 1; }
	@python3 tools/make_spice_screenshot.py $(MENU) $(SETTINGS) spice/screenshot.png

# spice/ holds what the Spices listing shows: a user-facing README and a
# landscape screenshot. The top-level README is for developers and its image
# paths do not exist inside the package.
spice: lint
	@test -f spice/README.md -a -f spice/screenshot.png || { \
	 echo "spice/README.md and spice/screenshot.png are required"; exit 1; }
	@rm -rf $(SPICEDIR)
	@mkdir -p $(SPICEDIR)/files/$(UUID)/po
	@cp -a $(SRCDIR)/. $(SPICEDIR)/files/$(UUID)/
	@cp $(SHAREDDIR)/*.js $(SPICEDIR)/files/$(UUID)/
	@cp po/*.po po/*.pot $(SPICEDIR)/files/$(UUID)/po/
	@cp info.json $(SPICEDIR)/
	@cp spice/README.md $(SPICEDIR)/
	@cp spice/screenshot.png $(SPICEDIR)/
	@find $(SPICEDIR) -name '*.mo' -delete
	@python3 tools/check_spice.py $(SPICEDIR) $(UUID)
	@echo "Spice layout built in $(SPICEDIR)"

VALIDATOR   := $(BUILDDIR)/validate-spice
VALIDATOR_URL := https://raw.githubusercontent.com/linuxmint/cinnamon-spices-extensions/master/validate-spice

$(VALIDATOR):
	@mkdir -p $(BUILDDIR)
	@echo "Fetching validate-spice from the cinnamon-spices repository..."
	@curl -fsSL $(VALIDATOR_URL) -o $(VALIDATOR)

validate: spice $(VALIDATOR)
	@cd $(BUILDDIR)/spice && python3 ../validate-spice $(UUID)

dist: lint
	@mkdir -p $(BUILDDIR)
	@rm -f $(ZIP)
	@cd src && zip -qr ../$(ZIP) $(UUID)
	@zip -qr $(ZIP) po
	@echo "Archive built: $(ZIP)"

# The landing page lives outside this repository; its deploy target carried an
# internal host name and server path, which do not belong in a public repo.
deploy: dist
	@echo
	@echo "For a cinnamon-spices submission run 'make spice' and 'make validate'."
	@echo "To install on this host run 'make install'."

clean:
	@rm -rf $(BUILDDIR)
	@echo "Build artefacts removed."

distclean: clean
	@rm -rf $(CONFIGDIR)
	@echo "Stored settings removed: $(CONFIGDIR)"

define ENABLE_SCRIPT
import subprocess, sys, ast
action, uuid = sys.argv[1], sys.argv[2]
key = ["gsettings", "get", "org.cinnamon", "enabled-extensions"]
raw = subprocess.check_output(key, text=True).strip()
current = [] if raw in ("@as []", "[]") else ast.literal_eval(raw)
if action == "add":
    if uuid in current:
        print("Already enabled: %s" % uuid); sys.exit(0)
    current.append(uuid)
else:
    if uuid not in current:
        print("Not enabled: %s" % uuid); sys.exit(0)
    current.remove(uuid)
value = "[" + ", ".join("'%s'" % u for u in current) + "]"
subprocess.check_call(["gsettings", "set", "org.cinnamon", "enabled-extensions", value])
print(("Enabled: %s" if action == "add" else "Disabled: %s") % uuid)
endef
export ENABLE_SCRIPT
