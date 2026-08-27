#!/usr/bin/env python3

import json
import os
import re
import sys


def fail(problems, text):
    problems.append(text)


def main():
    root, uuid = sys.argv[1], sys.argv[2]
    files = os.path.join(root, "files", uuid)
    problems = []

    readme = os.path.join(root, "README.md")
    if os.path.exists(readme):
        text = open(readme, encoding="utf-8").read()
        for ref in re.findall(r'!\[[^\]]*\]\(([^)]+)\)', text) + \
                   re.findall(r'<img[^>]+src="([^"]+)"', text):
            if ref.startswith(("http://", "https://", "data:")):
                continue
            if not os.path.exists(os.path.join(root, ref)):
                fail(problems, "README references a missing image: %s" % ref)
    else:
        fail(problems, "README.md is missing")

    meta_path = os.path.join(files, "metadata.json")
    meta = json.load(open(meta_path, encoding="utf-8"))
    raw = open(meta_path, "rb").read()
    if any(b > 127 for b in raw):
        fail(problems, "metadata.json contains non-ASCII characters")
    for field in ("uuid", "name", "description"):
        if not meta.get(field):
            fail(problems, "metadata.json lacks %s" % field)
    if meta.get("uuid") != uuid:
        fail(problems, "metadata.json uuid does not match the directory")
    for field in ("icon", "dangerous", "last-edited", "max-instances"):
        if field in meta:
            fail(problems, "metadata.json should not carry %s" % field)

    info = json.load(open(os.path.join(root, "info.json"), encoding="utf-8"))
    if not info.get("author") or any(c.isspace() for c in info["author"]):
        fail(problems, "info.json author must be a whitespace-free GitHub name")

    shot = os.path.join(root, "screenshot.png")
    try:
        from PIL import Image
        w, h = Image.open(shot).size
        if w < h:
            fail(problems, "screenshot is portrait (%dx%d); the listing shows landscape tiles" % (w, h))
        icon_w, icon_h = Image.open(os.path.join(files, "icon.png")).size
        if icon_w != icon_h:
            fail(problems, "icon.png is not square (%dx%d)" % (icon_w, icon_h))
    except ImportError:
        pass

    po_dir = os.path.join(files, "po")
    pots = [f for f in os.listdir(po_dir) if f.endswith(".pot")] if os.path.isdir(po_dir) else []
    if len(pots) != 1:
        fail(problems, "expected exactly one .pot in po/, found %d" % len(pots))

    for walk_root, _dirs, names in os.walk(root):
        for name in names:
            if name.endswith(".mo"):
                fail(problems, "compiled catalog shipped: %s" % name)

    if problems:
        for p in problems:
            print("FAIL  %s" % p)
        sys.exit(1)
    print("OK      spice package checks")


if __name__ == "__main__":
    main()
