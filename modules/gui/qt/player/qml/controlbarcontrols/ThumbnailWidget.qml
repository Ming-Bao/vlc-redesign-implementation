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
import VLC.Player

// artwork of the playing media; Figma palette "Thumbnail" is a #303030 rounded square
Rectangle {
    property bool paintOnly: false

    enabled: false

    implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
    radius: VLCStyle.dp(2, VLCStyle.scale)
    color: "#303030"   // fixed colour: thumbnail placeholder

    Image {
        anchors.fill: parent
        visible: status === Image.Ready
        source: parent.paintOnly ? "" : Player.artwork
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: parent.width
        sourceSize.height: parent.height
    }
}
