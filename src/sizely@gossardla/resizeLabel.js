const St = imports.gi.St;
const Main = imports.ui.main;

const Sizing = require('./sizing');

// Resize grab ops carry their direction in these bits. Keyboard resizing
// (Alt+F8) starts without a direction and sets the "unknown" bit until the
// first arrow key; moving, compositor and frame button grabs set neither.
const GRAB_OP_DIR_MASK = 0xf000;
const GRAB_OP_RESIZE_UNKNOWN = 0x200;

// Gap between the top edge of the frame and the label on windows without a
// server-side title bar, in logical pixels.
const TOP_MARGIN = 8;

function isResizeOp(op) {
    return (op & (GRAB_OP_DIR_MASK | GRAB_OP_RESIZE_UNKNOWN)) !== 0;
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(value, max));
}

// Shows the frame size of a window at its top while it is being resized and
// removes it as soon as the grab ends, i.e. when the mouse button is released.
class ResizeLabel {
    constructor(useLogical) {
        this._useLogical = useLogical;
        this._displaySignals = [];
        this._windowSignals = [];
        this._window = null;
        this._label = null;
    }

    enable() {
        if (this._displaySignals.length > 0) {
            return;
        }
        // Muffin 6.6 emits (display, display, window, op) - one argument more
        // than Cinnamon's own handlers assume. Take window and op from the
        // end so either form works.
        this._displaySignals = [
            global.display.connect("grab-op-begin", (...args) => this._begin(args[args.length - 2], args[args.length - 1])),
            global.display.connect("grab-op-end", () => this._end())
        ];
    }

    disable() {
        for (const id of this._displaySignals) {
            global.display.disconnect(id);
        }
        this._displaySignals = [];
        this._end();
    }

    _begin(window, op) {
        this._end();
        if (!window || !isResizeOp(op)) {
            return;
        }

        this._window = window;
        this._windowSignals = [
            window.connect("size-changed", () => this._update()),
            window.connect("position-changed", () => this._update()),
            window.connect("unmanaging", () => this._end())
        ];

        // Same style class as Cinnamon's own resize popup for terminals, so
        // the label follows the theme.
        this._label = new St.Label({ style_class: "resize-popup", important: true });
        Main.uiGroup.add_actor(this._label);
        this._update();
    }

    _end() {
        if (this._window) {
            for (const id of this._windowSignals) {
                this._window.disconnect(id);
            }
        }
        this._windowSignals = [];
        this._window = null;

        if (this._label) {
            this._label.destroy();
            this._label = null;
        }
    }

    _text(frame) {
        const scale = this._useLogical() ? Sizing.uiScale() : 1;
        return Math.round(frame.width / scale) + " × " + Math.round(frame.height / scale);
    }

    _update() {
        if (!this._window || !this._label) {
            return;
        }

        const frame = this._window.get_frame_rect();
        this._label.set_text(this._text(frame));

        const [, width] = this._label.get_preferred_width(-1);
        const [, height] = this._label.get_preferred_height(width);

        // Center the label on the server-side title bar when it is tall
        // enough, otherwise pin it just below the top edge of the frame.
        const titlebar = this._window.frame_rect_to_client_rect(frame).y - frame.y;
        let y = titlebar >= height
            ? frame.y + Math.floor((titlebar - height) / 2)
            : frame.y + Math.round(TOP_MARGIN * Sizing.uiScale());
        let x = frame.x + Math.floor((frame.width - width) / 2);

        // Keep it visible when the top of the window is off-screen.
        const monitor = Main.layoutManager.monitors[this._window.get_monitor()];
        if (monitor) {
            x = clamp(x, monitor.x, monitor.x + monitor.width - width);
            y = clamp(y, monitor.y, monitor.y + monitor.height - height);
        }

        this._label.set_position(x, y);
    }
}

module.exports = {
    ResizeLabel
};
