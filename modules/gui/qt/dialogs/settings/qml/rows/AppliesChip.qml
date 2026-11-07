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
import VLC.Widgets as Widgets

// The small grey "Next video" / "After restart" tag after a row's label (SettingsData.appliesText); empty hides it.
Rectangle {
    id: root

    required property var style         // the delegate's SettingsStyle
    property alias text: label.text

    visible: text.length > 0
    implicitWidth: label.implicitWidth + 2 * VLCStyle.dp(7, VLCStyle.scale)
    implicitHeight: label.implicitHeight + 2 * VLCStyle.dp(2, VLCStyle.scale)
    radius: VLCStyle.dp(4, VLCStyle.scale)
    color: root.style.chipBg

    Widgets.LabelExt {
        id: label

        anchors.centerIn: parent
        font.pixelSize: VLCStyle.dp(11, VLCStyle.scale)
        color: root.style.label
    }
}
