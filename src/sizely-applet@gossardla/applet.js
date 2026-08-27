const GLib = imports.gi.GLib;
const Gettext = imports.gettext;
const St = imports.gi.St;
const Applet = imports.ui.applet;
const Main = imports.ui.main;
const PopupMenu = imports.ui.popupMenu;
const Settings = imports.ui.settings;

const Sizing = require('./sizing');
const FAMILIES = Sizing.FAMILIES;

const UUID = "sizely-applet@gossardla";

Gettext.bindtextdomain(UUID, GLib.get_user_data_dir() + "/locale");

function _(str) {
    const translated = Gettext.dgettext(UUID, str);
    return translated === str ? str : translated;
}

class SizelyApplet extends Applet.IconApplet {
    _init(orientation, panelHeight, instanceId) {
        super._init(orientation, panelHeight, instanceId);

        this.set_applet_icon_symbolic_name("view-restore");
        this.set_applet_tooltip(_("Window size and position"));

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this.settings = new Settings.AppletSettings(this, UUID, instanceId);
        this.settings.bind("presets", "presets");
        this.settings.bind("size-unit", "sizeUnit");
        this.settings.bind("show-standard-resolutions", "showStandardResolutions");
        this.settings.bind("standard-center", "standardCenter");
        this.settings.bind("standard-fit-only", "standardFitOnly");
        for (const family of FAMILIES) {
            this.settings.bind("standard-family-" + family.id, "standardFamily_" + family.id);
        }

        this.menu.connect("open-state-changed", (menu, open) => {
            if (open) {
                this._rebuild();
            }
        });
    }

    on_applet_clicked() {
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        this.settings.finalize();
    }

    _useLogical() {
        return this.sizeUnit !== "physical";
    }

    /* The panel does not take focus, so the window that was active when the
     * menu opened is still the one to act on. It is captured up front all the
     * same: rebuilding happens before anything can steal focus. */
    _rebuild() {
        this.menu.removeAll();

        const window = Sizing.targetWindow();
        if (!window) {
            const item = new PopupMenu.PopupMenuItem(_("No active window"));
            item.setSensitive(false);
            this.menu.addMenuItem(item);
            return;
        }

        this._addTitle(window);

        const presets = Array.isArray(this.presets) ? this.presets : [];
        for (const preset of presets) {
            this._addItem(this.menu, this._presetLabel(preset),
                () => Sizing.resizeWindow(window, preset.width, preset.height,
                    preset.center, this._useLogical()));
        }
        if (presets.length > 0) {
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        this._addResolutions(window);

        this._addItem(this.menu, _("Center on Monitor"), () => Sizing.centerWindow(window));
    }

    _addTitle(window) {
        const title = window.get_title() || "";
        const item = new PopupMenu.PopupMenuItem(
            title.length > 44 ? title.slice(0, 43) + "…" : title);
        item.setSensitive(false);
        this.menu.addMenuItem(item);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    }

    _addResolutions(window) {
        if (!this.showStandardResolutions) {
            return;
        }

        const enabled = FAMILIES.filter(f => this["standardFamily_" + f.id]).map(f => f.id);
        const groups = Sizing.resolutionGroups(window, enabled, this.standardFitOnly,
            this._useLogical());
        if (groups.length === 0) {
            return;
        }

        const root = new PopupMenu.PopupSubMenuMenuItem(_("Standard Resolutions"));
        this.menu.addMenuItem(root);

        groups.forEach((group, index) => {
            if (index > 0) {
                root.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            }
            const heading = new PopupMenu.PopupMenuItem(group.label);
            heading.setSensitive(false);
            root.menu.addMenuItem(heading);

            for (const [w, h, name] of group.entries) {
                this._addItem(root.menu, Sizing.entryLabel(w, h, name),
                    () => Sizing.resizeWindow(window, w, h, this.standardCenter,
                        this._useLogical()));
            }
        });

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    }

    _addItem(target, label, callback) {
        const item = new PopupMenu.PopupMenuItem(label);
        item.connect("activate", () => callback());
        target.addMenuItem(item);
        return item;
    }

    _presetLabel(preset) {
        if (preset.label && preset.label.trim() !== "") {
            return preset.label;
        }
        return preset.width + " × " + preset.height;
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new SizelyApplet(orientation, panelHeight, instanceId);
}
