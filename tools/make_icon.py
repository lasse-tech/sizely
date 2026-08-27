#!/usr/bin/env python3

import sys
from PIL import Image, ImageDraw

SIZE = 256
SCALE = 4

MONITOR_LINE = (108, 117, 131, 255)
WINDOW_FILL = (74, 144, 217, 255)
TITLEBAR_FILL = (37, 99, 168, 255)
DOT = (255, 255, 255, 235)


def draw(path):
    s = SIZE * SCALE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    unit = s / 256.0

    m = 18 * unit
    d.rounded_rectangle([m, m, s - m, s - m],
                        radius=14 * unit, outline=MONITOR_LINE, width=int(8 * unit))

    w = 128 * unit
    h = 92 * unit
    x0 = (s - w) / 2
    y0 = (s - h) / 2
    radius = 9 * unit
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=radius, fill=WINDOW_FILL)

    bar = 26 * unit
    d.rounded_rectangle([x0, y0, x0 + w, y0 + bar + radius], radius=radius, fill=TITLEBAR_FILL)
    d.rectangle([x0, y0 + bar, x0 + w, y0 + bar + radius], fill=WINDOW_FILL)

    r = 3.6 * unit
    cy = y0 + bar / 2
    for i in range(3):
        cx = x0 + (13 + i * 15) * unit
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DOT)

    img.resize((SIZE, SIZE), Image.LANCZOS).save(path)
    print("%s: %d x %d" % (path, SIZE, SIZE))


if __name__ == "__main__":
    draw(sys.argv[1] if len(sys.argv) > 1 else "icon.png")
