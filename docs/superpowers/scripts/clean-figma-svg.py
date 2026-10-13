#!/usr/bin/python3 -I
"""Strip Figma component-set chrome from exported icon SVGs, in place.

A variant exported from the Figma icon set carries the set's #292929 background and
dashed frame; keep only the <g id="name=..."> group so FontForge imports just the icon.
Exits non-zero listing files that contain no drawable icon (e.g. an empty variant).

usage: clean-figma-svg.py FILE.svg...
"""
import sys
import re
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
DOT = re.compile(r"M\s*([\d.]+)[ ,]([\d.]+)\s*L\s*([\d.]+)[ ,]([\d.]+)")
empty = []
for path in sys.argv[1:]:
    root = ET.parse(path).getroot()
    icon = next((g for g in root.iter(f"{{{SVG}}}g") if g.get("id", "").startswith("name=")), None)
    if icon is None or not any(el.tag != f"{{{SVG}}}g" for el in icon.iter()):
        empty.append(path)
        continue
    out = ET.Element(f"{{{SVG}}}svg", {"width": "24", "height": "24", "viewBox": "0 0 24 24", "fill": "none"})
    for el in list(icon.iter()):
        if el.tag == f"{{{SVG}}}g":
            continue
        width = float(el.get("stroke-width", "0") or 0)
        dot = DOT.fullmatch((el.get("d") or "").strip())
        if (dot and width and el.get("stroke-linecap") == "round"
                and abs(float(dot.group(1)) - float(dot.group(3))) < 0.01
                and abs(float(dot.group(2)) - float(dot.group(4))) < 0.01):
            # zero-length round-capped stroke (Figma "more" dots): FontForge drops it, draw the dot
            x, y = float(dot.group(1)), float(dot.group(2))
            el.tag = f"{{{SVG}}}circle"
            el.attrib = {"cx": str(x), "cy": str(y), "r": str(width / 2), "fill": el.get("stroke")}
    out.append(icon)
    ET.ElementTree(out).write(path, encoding="unicode")
if empty:
    print("no icon in: " + " ".join(empty))
    sys.exit(1)
