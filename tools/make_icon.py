#!/usr/bin/env python3

import sys
from PIL import Image, ImageDraw

SIZE = 256
SCALE = 4

GREEN = (133, 196, 64, 255)
INK = (20, 38, 10, 255)
SYMBOLIC = (43, 43, 43, 255)
SET_SIZES = (16, 22, 24, 32, 48, 64, 128, 256)

USAGE = """Usage:
    python3 tools/make_icon.py [path]            256 px colour icon
    python3 tools/make_icon.py --set outdir      16/22/24/32/48/64/128/256
    python3 tools/make_icon.py --symbolic path   monochrome, transparent"""


def _draw(size, badge=True, color=INK, bg=GREEN):
    s = size * SCALE
    u = s / 256.0
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if badge:
        d.rounded_rectangle([16 * u, 16 * u, 240 * u, 240 * u],
                            radius=52 * u, fill=bg)

    w = 18 * u
    for pts in ([(56, 104), (56, 56), (104, 56)],
                [(200, 152), (200, 200), (152, 200)]):
        d.line([(x * u, y * u) for x, y in pts], fill=color,
               width=int(round(w)), joint="curve")
        for x, y in pts:
            r = w / 2.0
            d.ellipse([x * u - r, y * u - r, x * u + r, y * u + r], fill=color)

    return img.resize((size, size), Image.LANCZOS)


def save(path, size=SIZE, **kw):
    _draw(size, **kw).save(path)
    print("%s: %d x %d" % (path, size, size))


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--help":
        print(USAGE)
    elif args and args[0] == "--set":
        outdir = (args[1] if len(args) > 1 else ".").rstrip("/")
        for n in SET_SIZES:
            save("%s/sizely-icon-%d.png" % (outdir, n), n)
    elif args and args[0] == "--symbolic":
        save(args[1] if len(args) > 1 else "sizely-symbolic.png",
             badge=False, color=SYMBOLIC)
    else:
        save(args[0] if args else "icon.png")
