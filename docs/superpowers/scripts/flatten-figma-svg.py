#!/usr/bin/python3 -I
"""Flatten cleaned Figma icon SVGs into fill-only outlines, in place.

FontForge expands strokes on import, but a shape that is both filled and stroked comes in
as a ring whose inner contour cancels the fill. Import every drawable element on its own,
keep only the outer contour of filled+stroked shapes, merge, and write a fill-only SVG on a
1024 grid that makeIconFont.py imports as-is.

usage: flatten-figma-svg.py FILE.svg...   (run clean-figma-svg.py first)
"""
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET

import fontforge

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
DRAWABLE = {f"{{{SVG}}}{t}" for t in ("path", "rect", "circle", "ellipse", "line", "polyline", "polygon")}


def import_element(el):
    """FontForge glyph layer for one SVG element on the 24px canvas."""
    doc = ET.Element(f"{{{SVG}}}svg", {"width": "24", "height": "24", "viewBox": "0 0 24 24", "fill": "none"})
    doc.append(el)
    fd, tmp = tempfile.mkstemp(suffix=".svg")
    os.close(fd)
    ET.ElementTree(doc).write(tmp, encoding="unicode")
    font = fontforge.font()
    font.ascent, font.descent = 1024, 0
    glyph = font.createChar(0xE000)
    glyph.importOutlines(tmp)
    os.unlink(tmp)
    return glyph.foreground


def area(contour):
    x0, y0, x1, y1 = contour.boundingBox()
    return (x1 - x0) * (y1 - y0)


for path in sys.argv[1:]:
    root = ET.parse(path).getroot()
    merged = fontforge.layer()
    for el in [e for e in root.iter() if e.tag in DRAWABLE]:
        solid = el.get("fill", "none") != "none" and el.get("stroke", "none") != "none"
        layer = import_element(el)
        if solid and len(layer):
            outer = max(layer, key=area)          # ring outer edge == filled shape grown by the stroke
            outer.isClockwise() or outer.reverseDirection()
            layer = fontforge.layer()
            layer += outer
        merged += layer
    font = fontforge.font()
    font.ascent, font.descent = 1024, 0
    glyph = font.createChar(0xE000)
    glyph.foreground = merged
    glyph.correctDirection()   # elements import with mixed winding; orient contours by nesting
    glyph.removeOverlap()
    glyph.width = 1024
    fd, tmp = tempfile.mkstemp(suffix=".svg")
    os.close(fd)
    glyph.export(tmp)
    d = " ".join(re.findall(r'\bd="([^"]*)"', open(tmp).read(), re.S))
    os.unlink(tmp)
    open(path, "w").write('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
                          f'viewBox="0 0 1024 1024"><path fill="#000" d="{d.strip()}"/></svg>\n')
