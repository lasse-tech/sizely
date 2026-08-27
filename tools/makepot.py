#!/usr/bin/env python3

import json
import os
import re
import sys

JS_STRING = re.compile(r"""_\(\s*(?P<q>["'])(?P<text>(?:\\.|(?!(?P=q)).)*)(?P=q)\s*\)""")

SCHEMA_FIELDS = ("description", "tooltip", "units")


def unescape_js(text):
    return text.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\")


def escape_po(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def add(entries, text, reference):
    if not text or not text.strip():
        return
    entries.setdefault(text, []).append(reference)


def scan_js(path, entries):
    with open(path, encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            for match in JS_STRING.finditer(line):
                add(entries, unescape_js(match.group("text")),
                    "%s:%d" % (os.path.basename(path), lineno))


def scan_schema(path, entries):
    with open(path, encoding="utf-8") as handle:
        schema = json.load(handle)

    name = os.path.basename(path)
    for key, item in schema.items():
        if not isinstance(item, dict):
            continue

        for field in SCHEMA_FIELDS:
            add(entries, item.get(field), "%s:%s" % (name, key))

        options = item.get("options")
        if isinstance(options, dict):
            for label in options:
                add(entries, label, "%s:%s" % (name, key))

        for column in item.get("columns", []) or []:
            if isinstance(column, dict):
                add(entries, column.get("title"), "%s:%s" % (name, key))


def main():
    if len(sys.argv) != 3:
        sys.exit("Usage: makepot.py <xlet-directory> <output.pot>")

    xlet_dir, out_path = sys.argv[1], sys.argv[2]
    entries = {}

    for filename in sorted(os.listdir(xlet_dir)):
        full = os.path.join(xlet_dir, filename)
        if filename.endswith(".js"):
            scan_js(full, entries)
        elif filename == "settings-schema.json":
            scan_schema(full, entries)

    with open(out_path, "w", encoding="utf-8") as out:
        out.write(
            'msgid ""\n'
            'msgstr ""\n'
            '"Content-Type: text/plain; charset=UTF-8\\n"\n'
            '"Content-Transfer-Encoding: 8bit\\n"\n'
            '"MIME-Version: 1.0\\n"\n'
            '\n'
        )
        for text in sorted(entries):
            for reference in entries[text]:
                out.write("#: %s\n" % reference)
            out.write('msgid "%s"\n' % escape_po(text))
            out.write('msgstr ""\n\n')

    print("%s: %d strings" % (out_path, len(entries)))


if __name__ == "__main__":
    main()
