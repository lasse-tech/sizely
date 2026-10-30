REQUIRED    := clean distclean debug install uninstall deploy lint
HELP_VARS   := MENU SETTINGS DRY_RUN

.DEFAULT_GOAL := help

UUID        := sizely@gossardla
SRCDIR      := src/$(UUID)
XLETDIR     := $(HOME)/.local/share/cinnamon/extensions
DESTDIR     := $(XLETDIR)/$(UUID)
CONFIGDIR   := $(HOME)/.config/cinnamon/spices/$(UUID)
# XDG_DATA_HOME, else the spec default
LOCALEDIR   := $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME),$(HOME)/.local/share)/locale
POTFILE     := po/$(UUID).pot
POFILES     := $(wildcard po/*.po)
BUILDDIR    := build
SPICEDIR    := $(BUILDDIR)/spice/$(UUID)
ZIP         := $(BUILDDIR)/$(UUID).zip
JS_SOURCES  := $(wildcard $(SRCDIR)/*.js) $(wildcard tools/*.js)

VERSION     := $(shell python3 -c "import json; print(json.load(open('$(SRCDIR)/metadata.json'))['version'])")

# public export: what building and running need; design material stays on Forgejo
DIST_DIR     := dist
PUBLIC_DIR   := $(DIST_DIR)/public
PUBLIC_PATHS := .gitignore LICENSE Makefile README.md info.json po scripts spice src \
	tools/check_spice.py tools/make_icon.py tools/makepot.py tools/syntaxcheck.js \
	assets/png/sizely-icon-128.png
GITHUB_URL   := git@github.com:lasse-tech/sizely.git
PUBLIC_NAME  := Lars Gossard
PUBLIC_EMAIL := lars@lasse-tech.de

DBUS_SEND   := dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon

.PHONY: help install uninstall reinstall debug enable disable reload restart \
        logs lint check clean distclean reset-settings dist status pot install-locale \
        uninstall-locale i18n-check icon screenshot spice spice-shot validate deploy \
        public github

##@ General

## help: list targets
help:
	@$(foreach v,$(HELP_VARS),$(v)='$($(v))') awk -f scripts/make-help.awk $(firstword $(MAKEFILE_LIST))

## lint: JS syntax, ruff, translations, JSON, About version, Makefile comment rules
lint:
	@command -v cjs >/dev/null || { echo "cjs (Cinnamon JS) not found"; exit 1; }
	@command -v ruff >/dev/null || { echo "ruff not found"; exit 1; }
	@cjs tools/syntaxcheck.js $(JS_SOURCES)
	@ruff check --quiet tools/ && echo "OK      tools/*.py"
	@for po in $(POFILES); do msgfmt --check -o /dev/null $$po || exit 1; echo "OK      $$po"; done
	@python3 -c "import json; json.load(open('$(SRCDIR)/settings-schema.json')); print('OK      $(SRCDIR)/settings-schema.json')"
	@python3 -c "import json; json.load(open('$(SRCDIR)/metadata.json')); print('OK      $(SRCDIR)/metadata.json')"
	@python3 -c "$$ABOUT_CHECK" $(SRCDIR) $(VERSION)
	@awk -v required="$(REQUIRED)" -f scripts/make-lint.awk $(firstword $(MAKEFILE_LIST))

check: lint

##@ Install on this host

## install: install, compile translations and enable
install: lint install-locale
	@mkdir -p $(XLETDIR)
	@rm -rf $(DESTDIR)
	@cp -a $(SRCDIR) $(DESTDIR)
	@echo "Installed to $(DESTDIR)"
	@$(MAKE) --no-print-directory enable

## debug: link the source tree into the extensions directory and enable; edit, then make reload
debug: lint install-locale
	@mkdir -p $(XLETDIR)
	@rm -rf $(DESTDIR)
	@ln -s $(CURDIR)/$(SRCDIR) $(DESTDIR)
	@echo "Linked $(DESTDIR) -> $(CURDIR)/$(SRCDIR)"
	@$(MAKE) --no-print-directory enable

## uninstall: disable and remove what install or debug put in place
uninstall: disable uninstall-locale
	@rm -rf $(DESTDIR)
	@echo "Removed: $(DESTDIR)"

## reinstall: uninstall + install
reinstall: uninstall install

## enable: enable only (already installed)
enable:
	@python3 -c "$$ENABLE_SCRIPT" add $(UUID)

## disable: disable only
disable:
	@python3 -c "$$ENABLE_SCRIPT" remove $(UUID)

## status: show installation and activation state
status:
	@echo "Source:       $(SRCDIR)"
	@if [ -d $(DESTDIR) ]; then echo "Installed:    yes  ($(DESTDIR))"; else echo "Installed:    no"; fi
	@printf "Enabled:      "; \
	 gsettings get org.cinnamon enabled-extensions | grep -q "$(UUID)" && echo "yes" || echo "no"
	@printf "Settings:     "; \
	 if [ -d $(CONFIGDIR) ]; then echo "$(CONFIGDIR)"; else echo "(none yet)"; fi

## reload: reload the extension in the running Cinnamon
reload:
	@$(DBUS_SEND) org.Cinnamon.ReloadXlet string:'$(UUID)' string:'EXTENSION' >/dev/null
	@echo "Extension reloaded."

## restart: restart Cinnamon
restart:
	@$(DBUS_SEND) org.Cinnamon.RestartCinnamon boolean:true >/dev/null
	@echo "Restarting Cinnamon."

## logs: follow the Cinnamon log, filtered to this extension
logs:
	@echo "Following ~/.xsession-errors (filter: $(UUID)) - stop with Ctrl+C"
	@tail -n 50 -f $(HOME)/.xsession-errors | grep --line-buffered -E '$(UUID)|Cinnamon Error|JS ERROR'

## reset-settings: remove the stored settings of this extension
reset-settings:
	@rm -rf $(CONFIGDIR)
	@echo "Stored settings removed: $(CONFIGDIR)"

##@ Translations

## pot: regenerate the translation template
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

## i18n-check: compare translations against the template
i18n-check: pot
	@for po in $(POFILES); do \
		printf "%s: " $$po; \
		msgcmp $$po $(POTFILE) 2>&1 || exit 1; \
		echo "complete"; \
	done

##@ Assets

## MENU: window-menu capture for spice-shot
MENU ?=
## SETTINGS: settings-dialog capture for spice-shot
SETTINGS ?=

## icon: regenerate the extension icon
icon:
	@python3 tools/make_icon.py $(SRCDIR)/icon.png

## screenshot: capture screenshot.png from the running window menu
screenshot:
	@test -f tools/make_screenshot.py || { echo "tools/make_screenshot.py is not in the public export"; exit 1; }
	@python3 tools/make_screenshot.py screenshot.png

## spice-shot: rebuild spice/screenshot.png from MENU and SETTINGS
spice-shot:
	@test -n "$(MENU)" -a -n "$(SETTINGS)" || { \
	 echo "usage: make spice-shot MENU=menu.png SETTINGS=settings.png"; exit 1; }
	@test -f tools/make_spice_screenshot.py || { echo "tools/make_spice_screenshot.py is not in the public export"; exit 1; }
	@python3 tools/make_spice_screenshot.py $(MENU) $(SETTINGS) spice/screenshot.png

##@ Package

# spice/: user-facing README and landscape screenshot for the Spices listing
## spice: build the cinnamon-spices layout in build/spice
spice: lint
	@test -f spice/README.md -a -f spice/screenshot.png || { \
	 echo "spice/README.md and spice/screenshot.png are required"; exit 1; }
	@rm -rf $(SPICEDIR)
	@mkdir -p $(SPICEDIR)/files/$(UUID)/po
	@cp -a $(SRCDIR)/. $(SPICEDIR)/files/$(UUID)/
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

## validate: run the official validate-spice against the spice layout
validate: spice $(VALIDATOR)
	@cd $(BUILDDIR)/spice && python3 ../validate-spice $(UUID)

## dist: build a zip archive
dist: lint
	@mkdir -p $(BUILDDIR)
	@rm -f $(ZIP)
	@cd src && zip -qr ../$(ZIP) $(UUID)
	@zip -qr $(ZIP) po
	@echo "Archive built: $(ZIP)"

# no web server: distribution is the Spices pull request
## deploy: build the zip and point to the Spices submission
deploy: dist
	@echo
	@echo "For a cinnamon-spices submission run 'make spice' and 'make validate'."
	@echo "To install on this host run 'make install'."

##@ Public export

## DRY_RUN: 1 = make github commits in dist/github, pushes nothing
DRY_RUN ?= 0

## public: build the public export of HEAD into dist/public
public:
	rm -rf $(PUBLIC_DIR) && mkdir -p $(PUBLIC_DIR)
	git archive HEAD $(PUBLIC_PATHS) | tar -x -C $(PUBLIC_DIR)
	@cd $(PUBLIC_DIR) && find . -type f | sort

## github: commit the public export of HEAD on top of GitHub's main, fast-forward
github: public
	rm -rf $(DIST_DIR)/github && git clone -q $(GITHUB_URL) $(DIST_DIR)/github
	@cd $(DIST_DIR)/github && git checkout -q main \
		&& find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + \
		&& cp -r ../public/. . && git add -A \
		&& if git diff --cached --quiet; then echo "GitHub is up to date"; exit 0; fi \
		&& GIT_AUTHOR_NAME="$(PUBLIC_NAME)" GIT_AUTHOR_EMAIL="$(PUBLIC_EMAIL)" \
		GIT_COMMITTER_NAME="$(PUBLIC_NAME)" GIT_COMMITTER_EMAIL="$(PUBLIC_EMAIL)" \
		git commit -qm "Sizely $(VERSION) ($(shell git rev-parse --short HEAD))" \
		&& git show --format="%h %s" --stat=100 HEAD | sed '$$d'
	@if [ "$(DRY_RUN)" = "1" ]; then echo "DRY_RUN=1: nothing pushed, see $(DIST_DIR)/github"; \
	else cd $(DIST_DIR)/github && git push -q origin main && echo "pushed to GitHub"; fi

##@ Clean

## clean: remove build artefacts and the public export
clean:
	@rm -rf $(BUILDDIR) $(DIST_DIR)
	@echo "Build artefacts removed."

## distclean: clean plus ruff and Python caches
distclean: clean
	@rm -rf .ruff_cache tools/__pycache__
	@echo "Caches removed."

define ABOUT_CHECK
import json, sys
src, version = sys.argv[1], sys.argv[2]
label = json.load(open(src + "/settings-schema.json"))["about-version"]["description"]
if label != "Version " + version:
    sys.exit("FAIL    About shows '%s', metadata.json has %s" % (label, version))
print("OK      About version %s" % version)
endef
export ABOUT_CHECK

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
