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

T.Switch {
    id: root
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Switch; focused: root.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
    signal requested(bool on)

    implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
    // the owner binds `checked` to the real state; a click only asks for the change
    checkable: false
    onClicked: requested(!checked)

    indicator: Rectangle {
        anchors.fill: parent
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus

        Rectangle {   // track
            x: VLCStyle.dp(root.checked ? 3 : 32, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(33, VLCStyle.scale); height: VLCStyle.dp(26, VLCStyle.scale)
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: root.checked ? root._s.accentBg : root._s.face
        }
        Rectangle {   // knob
            x: VLCStyle.dp(root.checked ? 39 : 3, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(26, VLCStyle.scale); height: width
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: root.checked ? root._s.accentDim : root._s.knobOff
        }
        Widgets.LabelExt {
            x: root.checked ? VLCStyle.dp(10, VLCStyle.scale) : parent.width / 2 + VLCStyle.dp(2, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: root.checked ? qsTr("ON") : qsTr("OFF")
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            color: root.checked ? root._s.accent : root._s.label
        }
    }
}
