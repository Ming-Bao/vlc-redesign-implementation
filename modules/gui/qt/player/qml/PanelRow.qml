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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

// one 32 px row of the player card lists (Figma queue, bookmarks, chapters): leading item, label, trailing text
T.ItemDelegate {
    id: row

    property alias leading: leadingHolder.data
    property string trailingText
    property bool current: false
    property bool selected: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Item
    }
    // the palette is gone while a removed row is torn down
    readonly property bool _dark: theme.palette?.isDark ?? false

    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
    // the list keeps keyboard focus and moves its cursor; rows only take clicks
    focusPolicy: Qt.NoFocus
    // the view still focuses its current row: hand keys to the list first, or platforms where
    // Return presses a button (GNOME) turn Enter into a click instead of the list's action
    Keys.forwardTo: [ListView.view]

    background: Rectangle {
        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: row.selected ? Qt.rgba(1, 1, 1, 0.08)
                            : (row.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
    }

    contentItem: RowLayout {
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Item {
            id: leadingHolder
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: row.text
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: row.current ? theme.accent : (row._dark ? "#969696" : theme.fg.primary)
        }

        Widgets.LabelExt {
            visible: text.length > 0
            text: row.trailingText
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: row._dark ? "#6B6B6B" : theme.fg.secondary
        }
    }
}
