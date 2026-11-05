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
import QtQuick.Shapes

import VLC.Style

// Customize Player's outline around items and zones: 1 px #6B6B6B, dash 4/4 (Figma 2107:5604)
// An Item, as a Shape's implicit size is its path's: a control's background would size itself in a loop.
Item {
    id: root

    readonly property real _w: VLCStyle.dp(1, VLCStyle.scale)

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "#6B6B6B"
            strokeWidth: root._w
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            fillColor: "transparent"

            startX: root._w / 2
            startY: root._w / 2
            PathLine { x: root.width - root._w / 2; y: root._w / 2 }
            PathLine { x: root.width - root._w / 2; y: root.height - root._w / 2 }
            PathLine { x: root._w / 2; y: root.height - root._w / 2 }
            PathLine { x: root._w / 2; y: root._w / 2 }
        }
    }
}
