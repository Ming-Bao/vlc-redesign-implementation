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
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

Widgets.ComboBoxExt {
    id: root
    property bool fullWidth: false
    readonly property SettingsStyle _s: SettingsStyle { theme: root.colorContext }

    Layout.preferredWidth: fullWidth ? -1 : VLCStyle.dp(220, VLCStyle.scale)
    Layout.fillWidth: fullWidth
    Layout.alignment: Qt.AlignTop
    Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
    color: _s.value
    opacity: enabled ? 1.0 : _s.disabledOpacity

    background: Rectangle {
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: root.colorContext.visualFocus
        Rectangle {
            anchors.fill: parent; anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root._s.face
        }
    }
    contentItem: Widgets.LabelExt {
        leftPadding: VLCStyle.dp(18, VLCStyle.scale)
        rightPadding: root.indicator.width + VLCStyle.dp(14, VLCStyle.scale)
        text: root.displayText
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.value
    }
}
