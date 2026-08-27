UUID        := sizely@gossardla
SRCDIR      := src/$(UUID)
XLETDIR     := $(HOME)/.local/share/cinnamon/extensions
DESTDIR     := $(XLETDIR)/$(UUID)
CONFIGDIR   := $(HOME)/.config/cinnamon/spices/$(UUID)
LOCALEDIR   := $(HOME)/.local/share/locale
POTFILE     := po/$(UUID).pot
POFILES     := $(wildcard po/*.po)
BUILDDIR    := build
SPICEDIR    := $(BUILDDIR)/spice/$(UUID)
ZIP         := $(BUILDDIR)/$(UUID).zip
JS_SOURCES  := $(wildcard $(SRCDIR)/*.js) $(wildcard tools/*.js)

DBUS_SEND   := dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon

.PHONY: all help install uninstall reinstall enable disable reload restart \
        logs lint check clean distclean deploy deploy-check spices-package dist status pot install-locale \
        uninstall-locale i18n-check icon screenshot spice validate

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
	@echo "  make validate    run the official validate-spice against that layout"
	@echo "  make dist        build a zip archive"
	@echo "  make deploy      publish web/ to $(WEBURL)"
	@echo "  make deploy-check  check the deployed page and its CSP header"
	@echo "  make clean       remove build artefacts"
	@echo "  make distclean   clean + remove stored settings"

lint:
	@command -v cjs >/dev/null || { echo "cjs (Cinnamon JS) not found"; exit 1; }
	@cjs tools/syntaxcheck.js $(JS_SOURCES)
	@for po in $(POFILES); do msgfmt --check -o /dev/null $$po && echo "OK      $$po"; done
	@python3 -c "import json; json.load(open('$(SRCDIR)/settings-schema.json')); print('OK      $(SRCDIR)/settings-schema.json')"
	@python3 -c "import json; json.load(open('$(SRCDIR)/metadata.json')); print('OK      $(SRCDIR)/metadata.json')"

check: lint

install: lint install-locale
	@mkdir -p $(XLETDIR)
	@rm -rf $(DESTDIR)
	@cp -a $(SRCDIR) $(DESTDIR)
	@echo "Installed to $(DESTDIR)"
	@$(MAKE) --no-print-directory enable

uninstall: disable uninstall-locale
	@rm -rf $(DESTDIR)
	@echo "Removed: $(DESTDIR)"

reinstall: uninstall install

pot:
	@python3 tools/makepot.py $(SRCDIR) $(POTFILE)

install-locale:
	@for po in $(POFILES); do \
		lang=$$(basename $$po .po); \
		mkdir -p $(LOCALEDIR)/$$lang/LC_MESSAGES; \
		msgfmt -o $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo $$po || exit 1; \
		echo "Translation installed: $$lang"; \
	done

uninstall-locale:
	@for po in $(POFILES); do \
		lang=$$(basename $$po .po); \
		rm -f $(LOCALEDIR)/$$lang/LC_MESSAGES/$(UUID).mo; \
	done
	@echo "Translations removed."

i18n-check: pot
	@for po in $(POFILES); do \
		printf "%s: " $$po; \
		msgcmp $$po $(POTFILE) 2>&1 && echo "complete"; \
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
	@echo "Extension reloaded."

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

spice: lint
	@rm -rf $(SPICEDIR)
	@mkdir -p $(SPICEDIR)/files/$(UUID)/po
	@cp -a $(SRCDIR)/. $(SPICEDIR)/files/$(UUID)/
	@cp po/*.po po/*.pot $(SPICEDIR)/files/$(UUID)/po/
	@cp info.json $(SPICEDIR)/
	@cp README.md $(SPICEDIR)/
	@if [ -f screenshot.png ]; then cp screenshot.png $(SPICEDIR)/; \
	 else echo "WARNING: screenshot.png is missing - run 'make screenshot'"; fi
	@find $(SPICEDIR) -name '*.mo' -delete
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

WEBDIR      := web
WEBHOST     := REDACTED
WEBPATH     := /REDACTED/sizely
WEBURL      := https://example.invalid/sizely/

# The landing page is served from the hosting site document root, so it inherits
# that site's CSP: no inline script, no external fonts. Keep it that way.
deploy:
	@test -f $(WEBDIR)/index.html || { echo "$(WEBDIR)/index.html missing"; exit 1; }
	@grep -q "<script>" $(WEBDIR)/index.html && { \
	 echo "refusing: inline <script> violates the site CSP (script-src 'self')"; exit 1; } || true
	@grep -qE '(src\|href)="https?://(fonts\.googleapis\|fonts\.gstatic)' $(WEBDIR)/index.html && { \
	 echo "refusing: external fonts violate the site CSP (font-src 'self')"; exit 1; } || true
	@rsync -a --delete --chmod=D755,F644 -e ssh $(WEBDIR)/ $(WEBHOST):$(WEBPATH)/
	@echo "Deployed to $(WEBHOST):$(WEBPATH)"
	@printf "%s -> HTTP " "$(WEBURL)"; curl -sS -o /dev/null -w "%{http_code}\n" $(WEBURL)

deploy-check:
	@printf "%-42s " "$(WEBURL)"; curl -sS -o /dev/null -w "%{http_code}\n" $(WEBURL)
	@curl -sSI $(WEBURL) | grep -i content-security-policy | sed 's/^/  /'

spices-package: dist
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
