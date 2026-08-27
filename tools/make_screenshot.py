#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import time

UUID = "sizely@gossardla"
TITLE_MARKER = "Sizely"
PADDING = 0


def cinnamon_eval(code):
    wrapped = ("(function(){ try { return (%s); } "
               "catch(e) { return 'ERROR: ' + e.toString(); } })()" % code)
    out = subprocess.run(
        ["gdbus", "call", "--session", "--dest", "org.Cinnamon",
         "--object-path", "/org/Cinnamon", "--method", "org.Cinnamon.Eval", wrapped],
        capture_output=True, text=True, check=True).stdout.strip()

    if not out.startswith("(true,"):
        raise RuntimeError("Eval failed: %s" % out)

    payload = out[out.index("'") + 1:out.rindex("'")]
    payload = payload.encode().decode("unicode_escape")
    if payload.startswith('"') and payload.endswith('"'):
        payload = json.loads(payload)
    if isinstance(payload, str) and payload.startswith("ERROR:"):
        raise RuntimeError(payload)
    return payload


OPEN_MENU = """
(function(){
  let St = imports.gi.St;
  let WM = imports.ui.windowMenu;
  let w = global.get_window_actors().map(a => a.meta_window)
           .filter(x => (x.get_title()||'').indexOf('%(marker)s') >= 0)[0];
  if (!w) return 'ERROR: no window titled %(marker)s';

  let area = w.get_work_area_current_monitor();
  let fw = Math.min(1500, area.width - 200);
  let fh = Math.min(1750, area.height - 120);
  let fx = area.x + Math.floor((area.width - fw) / 2);
  let fy = area.y + Math.floor((area.height - fh) / 2);
  w.move_resize_frame(true, fx, fy, fw, fh);
  w.activate(global.get_current_time());

  let src = new St.Widget();
  imports.ui.main.uiGroup.add_actor(src);
  src.set_position(fx + 60, fy + 90);
  src.set_size(1, 1);

  global.__sizelyShot = { menu: new WM.WindowMenu(w, src), src: src };
  let menu = global.__sizelyShot.menu;
  menu.open();

  let std = menu._getMenuItems().filter(i => i.menu && i.origLabel
      && i.origLabel.indexOf('Resolution') >= 0)[0];
  if (std) std.menu.open();
  return 'opened';
})()
"""

MENU_RECT = """
(function(){
  let s = global.__sizelyShot;
  if (!s) return 'ERROR: no menu';
  let box = a => {
    let [x, y] = a.get_transformed_position();
    let [w, h] = a.get_transformed_size();
    return [x, y, w, h];
  };
  let boxes = [box(s.menu.actor)];
  let walk = m => {
    for (let i of m._getMenuItems()) {
      if (i.menu && i.menu.isOpen) {
        boxes.push(box(i.menu.actor));
        walk(i.menu);
      }
    }
  };
  walk(s.menu);
  let x1 = Math.min(...boxes.map(b => b[0]));
  let y1 = Math.min(...boxes.map(b => b[1]));
  let x2 = Math.max(...boxes.map(b => b[0] + b[2]));
  let y2 = Math.max(...boxes.map(b => b[1] + b[3]));
  return JSON.stringify([Math.floor(x1), Math.floor(y1),
                         Math.ceil(x2 - x1), Math.ceil(y2 - y1)]);
})()
"""

CLOSE_MENU = """
(function(){
  let s = global.__sizelyShot;
  if (!s) return 'nothing to close';
  s.menu.close(false);
  s.menu.destroy();
  s.src.destroy();
  global.__sizelyShot = null;
  return 'closed';
})()
"""


def main():
    out_path = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "screenshot.png")

    print("Opening the window menu...")
    cinnamon_eval(OPEN_MENU % {"marker": TITLE_MARKER})
    time.sleep(1.2)

    try:
        rect = json.loads(cinnamon_eval(MENU_RECT))
        x, y, w, h = rect
        x, y = max(0, x - PADDING), max(0, y - PADDING)
        w, h = w + 2 * PADDING, h + 2 * PADDING
        print("Menu area: %d x %d at %d, %d" % (w, h, x, y))

        subprocess.run(
            ["gdbus", "call", "--session", "--dest", "org.Cinnamon",
             "--object-path", "/org/Cinnamon", "--method", "org.Cinnamon.ScreenshotArea",
             "false", str(x), str(y), str(w), str(h), "false", out_path],
            capture_output=True, text=True, check=True)
        time.sleep(1.0)
    finally:
        cinnamon_eval(CLOSE_MENU)

    if not os.path.exists(out_path):
        sys.exit("Screenshot was not written: %s" % out_path)

    from PIL import Image
    im = Image.open(out_path)
    print("%s: %d x %d" % (out_path, im.size[0], im.size[1]))


if __name__ == "__main__":
    main()
