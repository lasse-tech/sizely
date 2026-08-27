#!/usr/bin/env python3

import sys
from PIL import Image

WIDTH, HEIGHT = 1280, 720
BG = (46, 52, 64)
PAD = 32
GAP = 28


def compose(menu_path, settings_path, out_path):
    menu = Image.open(menu_path).convert("RGBA")
    settings = Image.open(settings_path).convert("RGBA")

    inner_h = HEIGHT - 2 * PAD
    menu_w = int(menu.width * inner_h / menu.height)
    if menu_w > WIDTH * 0.34:
        menu_w = int(WIDTH * 0.34)
        inner_menu_h = int(menu.height * menu_w / menu.width)
    else:
        inner_menu_h = inner_h
    menu = menu.resize((menu_w, inner_menu_h), Image.LANCZOS)

    settings_w = WIDTH - 2 * PAD - GAP - menu_w
    settings_h = int(settings.height * settings_w / settings.width)
    if settings_h > inner_h:
        settings_h = inner_h
        settings_w = int(settings.width * settings_h / settings.height)
    settings = settings.resize((settings_w, settings_h), Image.LANCZOS)

    canvas = Image.new("RGB", (WIDTH, HEIGHT), BG)
    canvas.paste(menu, (PAD, (HEIGHT - menu.height) // 2), menu)
    canvas.paste(settings, (WIDTH - PAD - settings.width, (HEIGHT - settings.height) // 2), settings)
    canvas.save(out_path, optimize=True)
    print("%s: %d x %d" % (out_path, WIDTH, HEIGHT))


if __name__ == "__main__":
    compose(sys.argv[1], sys.argv[2], sys.argv[3])
