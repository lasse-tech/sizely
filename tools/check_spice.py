#!/usr/bin/env python3

import json
import os
import re
import sys
from pathlib import Path

GITHUB_LOGIN = re.compile(r"[A-Za-z0-9](?:-?[A-Za-z0-9]){0,38}")


def fail(problems, text):
    problems.append(text)


def main():
    root, uuid = sys.argv[1], sys.argv[2]
    files = os.path.join(root, "files", uuid)
    problems = []

    readme = os.path.join(root, "README.md")
    if os.path.exists(readme):
        text = Path(readme).read_text(encoding="utf-8")
        for ref in re.findall(r'!\[[^\]]*\]\(([^)]+)\)', text) + \
                   re.findall(r'<img[^>]+src="([^"]+)"', text):
            if ref.startswith(("http://", "https://", "data:")):
                continue
            if not os.path.exists(os.path.join(root, ref)):
                fail(problems, f"README references a missing image: {ref}")
    else:
        fail(problems, "README.md is missing")

    meta_path = os.path.join(files, "metadata.json")
    raw = Path(meta_path).read_bytes()
    meta = json.loads(raw)
    if any(b > 127 for b in raw):
        fail(problems, "metadata.json contains non-ASCII characters")
    for field in ("uuid", "name", "description"):
        if not meta.get(field):
            fail(problems, f"metadata.json lacks {field}")
    if meta.get("uuid") != uuid:
        fail(problems, "metadata.json uuid does not match the directory")
    for field in ("icon", "dangerous", "last-edited", "max-instances"):
        if field in meta:
            fail(problems, f"metadata.json should not carry {field}")

    info = json.loads(Path(root, "info.json").read_text(encoding="utf-8"))
    if not GITHUB_LOGIN.fullmatch(info.get("author", "")):
        fail(problems, "info.json author must be the maintainer's GitHub user name")

    shot = os.path.join(root, "screenshot.png")
    try:
        from PIL import Image
        w, h = Image.open(shot).size
        if w < h:
            fail(problems, f"screenshot is portrait ({w}x{h}); the listing shows landscape tiles")
        icon_w, icon_h = Image.open(os.path.join(files, "icon.png")).size
        if icon_w != icon_h:
            fail(problems, f"icon.png is not square ({icon_w}x{icon_h})")
    except ImportError:
        pass

    po_dir = os.path.join(files, "po")
    pots = [f for f in os.listdir(po_dir) if f.endswith(".pot")] if os.path.isdir(po_dir) else []
    if len(pots) != 1:
        fail(problems, f"expected exactly one .pot in po/, found {len(pots)}")

    for walk_root, _dirs, names in os.walk(root):
        for name in names:
            if name.endswith(".mo"):
                fail(problems, f"compiled catalog shipped: {name}")

    if problems:
        for p in problems:
            print(f"FAIL  {p}")
        sys.exit(1)
    print("OK      spice package checks")


if __name__ == "__main__":
    main()
