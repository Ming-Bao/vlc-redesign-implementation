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

// A dashed line made of Rectangles: the static Qt of the Windows and macOS packages is built
// without Canvas, paths and QtQuick.Shapes (contrib/src/qtdeclarative/rules.mak).
// Horizontal unless `vertical`; dashes are `dash` line widths long, gaps `gap`.
Item {
    id: root

    property color color
    property real lineWidth: VLCStyle.dp(1, VLCStyle.scale)
    property real dash: 4
    property real gap: dash
    property bool vertical: false

    readonly property real _length: vertical ? height : width
    readonly property real _step: (dash + gap) * lineWidth

    implicitWidth: vertical ? lineWidth : 0
    implicitHeight: vertical ? 0 : lineWidth

    Repeater {
        model: root._step > 0 ? Math.max(0, Math.ceil(root._length / root._step)) : 0

        Rectangle {
            required property int index

            readonly property real _at: index * root._step
            readonly property real _size: Math.min(root.dash * root.lineWidth, root._length - _at)

            x: root.vertical ? 0 : _at
            y: root.vertical ? _at : 0
            width: root.vertical ? root.lineWidth : _size
            height: root.vertical ? _size : root.lineWidth
            color: root.color
        }
    }
}
