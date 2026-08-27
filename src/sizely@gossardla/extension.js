const GLib = imports.gi.GLib;
const Gettext = imports.gettext;
const Meta = imports.gi.Meta;
const Main = imports.ui.main;
const Settings = imports.ui.settings;
const PopupMenu = imports.ui.popupMenu;
const WindowMenu = imports.ui.windowMenu;

const { FAMILIES } = require('./resolutions');

const UUID = "sizely@gossardla";
const HOTKEY_CENTER = "sizely-center";
const HOTKEY_PRESET_PREFIX = "sizely-preset-";
const PRESET_HOTKEY_SLOTS = 5;

let extension = null;

Gettext.bindtextdomain(UUID, GLib.get_home_dir() + "/.local/share/locale");

function _(str) {
    const translated = Gettext.dgettext(UUID, str);
    return translated === str ? str : translated;
}

function _log(message) {
    global.log("[" + UUID + "] " + message);
}

function _logError(message, error) {
    global.logError("[" + UUID + "] " + message + ": " + error);
}

class Sizely {
    constructor(uuid) {
        this.uuid = uuid;
        this._origBuildMenu = null;
        this._presetHotkeyCount = 0;

        this.settings = new Settings.ExtensionSettings(this, uuid);
        this.settings.bind("presets", "presets", () => this._bindPresetHotkeys());
        this.settings.bind("center-keybinding", "centerKeybinding", () => this._bindCenterHotkey());
        this.settings.bind("size-unit", "sizeUnit");
        this.settings.bind("use-submenu", "useSubmenu");
        this.settings.bind("show-center-item", "showCenterItem");
        this.settings.bind("show-in-window-menu", "showInWindowMenu");

        for (let slot = 1; slot <= PRESET_HOTKEY_SLOTS; slot++) {
            this.settings.bind("preset-" + slot + "-keybinding",
                "presetKeybinding" + slot, () => this._bindPresetHotkeys());
        }

        this.settings.bind("show-standard-resolutions", "showStandardResolutions");
        this.settings.bind("standard-center", "standardCenter");
        this.settings.bind("standard-fit-only", "standardFitOnly");
        for (const family of FAMILIES) {
            this.settings.bind("standard-family-" + family.id, "standardFamily_" + family.id);
        }
    }

    enable() {
        this._patchWindowMenu();
        this._bindCenterHotkey();
        this._bindPresetHotkeys();
    }

    disable() {
        this._unpatchWindowMenu();
        Main.keybindingManager.removeHotKey(HOTKEY_CENTER);
        this._unbindPresetHotkeys();
        this.settings.finalize();
    }

    _scale(value, useLogical) {
        if (!useLogical) {
            return value;
        }
        return Math.round(value * global.ui_scale);
    }

    _targetWindow() {
        return global.display.get_focus_window();
    }

    _prepare(window) {
        if (!window || window.get_window_type() === Meta.WindowType.DESKTOP) {
            return false;
        }
        if (window.is_fullscreen()) {
            return false;
        }
        if (window.get_maximized() !== 0) {
            window.unmaximize(Meta.MaximizeFlags.BOTH);
        }
        if (window.tile_type !== undefined && window.tile_type !== Meta.WindowTileType.NONE) {
            window.unmaximize(Meta.MaximizeFlags.BOTH);
        }
        return true;
    }

    resizeWindow(window, width, height, center, useLogical) {
        if (!this._prepare(window)) {
            return;
        }
        if (!window.resizeable) {
            _log("Window is not resizable: " + window.get_title());
            return;
        }

        const area = window.get_work_area_current_monitor();
        const frame = window.get_frame_rect();

        const w = Math.max(1, Math.min(this._scale(width, useLogical), area.width));
        const h = Math.max(1, Math.min(this._scale(height, useLogical), area.height));

        let x;
        let y;
        if (center) {
            x = area.x + Math.floor((area.width - w) / 2);
            y = area.y + Math.floor((area.height - h) / 2);
        } else {
            x = Math.max(area.x, Math.min(frame.x, area.x + area.width - w));
            y = Math.max(area.y, Math.min(frame.y, area.y + area.height - h));
        }

        window.move_resize_frame(true, x, y, w, h);
    }

    centerWindow(window) {
        if (!this._prepare(window)) {
            return;
        }

        const area = window.get_work_area_current_monitor();
        const frame = window.get_frame_rect();

        const w = Math.min(frame.width, area.width);
        const h = Math.min(frame.height, area.height);

        window.move_resize_frame(true,
            area.x + Math.floor((area.width - w) / 2),
            area.y + Math.floor((area.height - h) / 2),
            w, h);
    }

    _patchWindowMenu() {
        if (this._origBuildMenu) {
            return;
        }

        const self = this;
        this._origBuildMenu = WindowMenu.WindowMenu.prototype._buildMenu;

        WindowMenu.WindowMenu.prototype._buildMenu = function(window) {
            self._origBuildMenu.call(this, window);
            try {
                self._injectItems(this, window);
            } catch (e) {
                _logError("Failed to extend the window menu", e);
            }
        };
    }

    _unpatchWindowMenu() {
        if (!this._origBuildMenu) {
            return;
        }
        WindowMenu.WindowMenu.prototype._buildMenu = this._origBuildMenu;
        this._origBuildMenu = null;
    }

    _addAction(menu, target, position, title, callback) {
        const item = new WindowMenu.MnemonicLeftOrnamentedMenuItem(title);
        target.addMenuItem(item, position);
        item.connect("activate", (o, event) => callback(event));
        menu._items.push(item);
        return item;
    }

    _injectItems(menu, window) {
        if (!this.showInWindowMenu) {
            return;
        }
        if (window.get_window_type() === Meta.WindowType.DESKTOP) {
            return;
        }

        const presets = Array.isArray(this.presets) ? this.presets : [];
        if (presets.length === 0 && !this.showCenterItem && !this.showStandardResolutions) {
            return;
        }

        let at = Math.max(0, menu._getMenuItems().length - 2);

        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem(), at++);

        if (presets.length > 0) {
            if (this.useSubmenu) {
                const sub = new WindowMenu.MnemonicSubMenuMenuItem(_("_Size"));
                menu.addMenuItem(sub, at++);
                menu._items.push(sub);
                for (const preset of presets) {
                    this._addAction(menu, sub.menu, undefined, this._presetLabel(preset),
                        () => this.resizeWindow(window, preset.width, preset.height, preset.center,
                            this.sizeUnit === "logical"));
                }
            } else {
                for (const preset of presets) {
                    this._addAction(menu, menu, at++, this._presetLabel(preset),
                        () => this.resizeWindow(window, preset.width, preset.height, preset.center,
                            this.sizeUnit === "logical"));
                }
            }
        }

        at = this._injectStandardResolutions(menu, window, at);

        if (this.showCenterItem) {
            const item = this._addAction(menu, menu, at++, _("C_enter on Monitor"),
                () => this.centerWindow(window));
            item.setIcon("view-restore-symbolic");
        }
    }

    _injectStandardResolutions(menu, window, at) {
        if (!this.showStandardResolutions) {
            return at;
        }

        const families = FAMILIES.filter(f => this["standardFamily_" + f.id]);
        if (families.length === 0) {
            return at;
        }

        const area = window.get_work_area_current_monitor();
        const root = new WindowMenu.MnemonicSubMenuMenuItem(_("Stan_dard Resolutions"));
        let added = 0;

        for (const family of families) {
            const entries = family.entries.filter(([w, h]) =>
                !this.standardFitOnly || (w <= area.width && h <= area.height));
            if (entries.length === 0) {
                continue;
            }

            const group = new PopupMenu.PopupSubMenuMenuItem(family.label);
            root.menu.addMenuItem(group);

            for (const [w, h, name] of entries) {
                const item = new PopupMenu.PopupMenuItem(w + " × " + h + "   " + name);
                item.connect("activate", () =>
                    this.resizeWindow(window, w, h, this.standardCenter, false));
                group.menu.addMenuItem(item);
            }
            added++;
        }

        if (added === 0) {
            root.destroy();
            return at;
        }

        menu.addMenuItem(root, at++);
        menu._items.push(root);
        return at;
    }

    _presetLabel(preset) {
        if (preset.label && preset.label.trim() !== "") {
            return preset.label;
        }
        return preset.width + " × " + preset.height;
    }

    _bindCenterHotkey() {
        Main.keybindingManager.removeHotKey(HOTKEY_CENTER);
        if (!this.centerKeybinding || this.centerKeybinding === "::") {
            return;
        }
        Main.keybindingManager.addHotKey(HOTKEY_CENTER, this.centerKeybinding,
            () => this.centerWindow(this._targetWindow()));
    }

    _bindPresetHotkeys() {
        this._unbindPresetHotkeys();

        const presets = Array.isArray(this.presets) ? this.presets : [];

        for (let slot = 1; slot <= PRESET_HOTKEY_SLOTS; slot++) {
            const binding = this["presetKeybinding" + slot];
            if (!binding || binding === "::") {
                continue;
            }
            const preset = presets[slot - 1];
            if (!preset) {
                continue;
            }
            Main.keybindingManager.addHotKey(HOTKEY_PRESET_PREFIX + slot, binding,
                () => this.resizeWindow(this._targetWindow(), preset.width, preset.height,
                    preset.center, this.sizeUnit === "logical"));
        }
        this._presetHotkeyCount = PRESET_HOTKEY_SLOTS;
    }

    _unbindPresetHotkeys() {
        for (let slot = 1; slot <= this._presetHotkeyCount; slot++) {
            Main.keybindingManager.removeHotKey(HOTKEY_PRESET_PREFIX + slot);
        }
        this._presetHotkeyCount = 0;
    }
}

function init(metadata) {
    extension = new Sizely(metadata.uuid);
}

function enable() {
    extension.enable();
}

function disable() {
    extension.disable();
    extension = null;
}
