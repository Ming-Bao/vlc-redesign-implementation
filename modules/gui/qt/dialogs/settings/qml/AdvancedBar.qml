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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// The "Advanced Options" bar (Figma 3046:9363): full width, 38 high, a right chevron when closed, down when open.
T.AbstractButton {
    id: root

    property bool open: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    implicitHeight: VLCStyle.dp(38, VLCStyle.scale)
    text: qsTr("Advanced Options")
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: text

    background: Rectangle {
        radius: VLCStyle.dp(2, VLCStyle.scale)
        color: root._s.advancedBg
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }

    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.LabelExt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.rowLabel
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(24, VLCStyle.scale)
                height: width
                sourceSize: Qt.size(width, height)
                source: root.open ? "qrc:///redesign/settings/chevron-down.svg" : "qrc:///redesign/settings/chevron-right.svg"
            }
        }
    }
}
