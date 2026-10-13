#!/usr/bin/python3 -I
"""Check the icon font against pixmaps/redesign/mapping.json.

Every mapped key must point at ./redesign/<svg> in VLCIcons.json and its glyph in
VLCIcons.ttf must have the contour count FontForge gets from importing that SVG.
Keys that are not mapped must still have a non-empty glyph.

usage: check-icon-font.py modules/gui/qt/pixmaps
"""
import json
import sys

import fontforge

base = sys.argv[1]
mapping = json.load(open(f"{base}/redesign/mapping.json"))
model = json.load(open(f"{base}/VLCIcons.json"))
font = fontforge.open(f"{base}/VLCIcons.ttf")
order = [g["key"] for g in model["glyphs"]]
bad = []
mapped = set()
for svg, keys in mapping.items():
    ref = fontforge.font()
    c = ref.createChar(0xE000)
    c.importOutlines(f"{base}/redesign/{svg}")
    for key in keys:
        mapped.add(key)
        if key not in order:
            bad.append(f"{key}: missing from VLCIcons.json")
            continue
        i = order.index(key)
        if model["glyphs"][i]["path"] != f"./redesign/{svg}":
            bad.append(f"{key}: path {model['glyphs'][i]['path']}")
        elif 0xE000 + i not in font or len(font[0xE000 + i].foreground) != len(c.foreground):
            bad.append(f"{key}: glyph does not match {svg}")
for i, key in enumerate(order):
    if key not in mapped and (0xE000 + i not in font or len(font[0xE000 + i].foreground) == 0):
        bad.append(f"{key}: unmapped glyph is empty")
print("\n".join(bad) or "icon font OK")
sys.exit(1 if bad else 0)
