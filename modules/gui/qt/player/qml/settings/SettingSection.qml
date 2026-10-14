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

ColumnLayout {
    id: root
    property alias title: titleLabel.text
    property bool divider: true
    default property alias content: body.data

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    spacing: 0

    Rectangle { visible: root.divider; Layout.fillWidth: true; implicitHeight: 1; color: root._s.divider }
    Widgets.LabelExt {
        id: titleLabel
        Layout.leftMargin: VLCStyle.dp(24, VLCStyle.scale)
        Layout.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
        font.weight: Font.Medium
        color: root._s.title
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.topMargin: VLCStyle.dp(10, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(5, VLCStyle.scale)
    }
}
