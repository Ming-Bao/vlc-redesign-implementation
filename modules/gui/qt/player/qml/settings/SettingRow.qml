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

RowLayout {
    id: root
    property alias label: lbl.text
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
    spacing: VLCStyle.dp(12, VLCStyle.scale)

    Widgets.LabelExt {
        id: lbl
        Layout.fillWidth: true
        leftPadding: VLCStyle.dp(4, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.label
        elide: Text.ElideRight
    }
}
