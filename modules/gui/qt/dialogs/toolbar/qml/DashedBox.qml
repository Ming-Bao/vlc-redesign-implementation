/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.Style

// Customize Player's outline around items and zones: 1 px FG/A3, dash 4/4 (Figma 2107:5604)
// A Canvas, not QtQuick.Shapes: static Qt (Windows, macOS) does not link Shapes.
Canvas {
    id: root

    readonly property real _w: VLCStyle.dp(1, VLCStyle.scale)
    readonly property color _color: VLCStyle.palette.tokens.fgA3   // the same in both themes

    on_ColorChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = _color
        ctx.lineWidth = _w
        ctx.setLineDash([4, 4])   // in units of the line width
        ctx.strokeRect(_w / 2, _w / 2, width - _w, height - _w)
    }
}
