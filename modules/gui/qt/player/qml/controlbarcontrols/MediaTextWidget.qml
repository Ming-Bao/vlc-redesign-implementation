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

import VLC.MainInterface
import VLC.Style
import VLC.Player

// one line of text about the playing media: field is "file", "artist", "folder" or "playlist"
Item {
    id: root

    property string field: "file"
    property bool paintOnly: false

    enabled: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // path pieces of a local file URL, [] for other media
    readonly property var _parts: {
        const url = Player.url.toString()
        return url.startsWith("file:") ? decodeURIComponent(url).split("/") : []
    }

    // ponytail: capped so one long name cannot push the other controls out; make it fill the zone if a Figma frame shows that
    implicitWidth: Math.min(label.implicitWidth, VLCStyle.dp(300, VLCStyle.scale))
    implicitHeight: label.implicitHeight

    T.Label {
        id: label

        anchors.fill: parent

        text: {
            if (root.paintOnly)
                return qsTr("Title")
            switch (root.field) {
            case "artist": return Player.artist
            case "folder": return root._parts.length > 2 ? root._parts[root._parts.length - 2] : ""
            case "playlist": return qsTr("Play Queue")
            default: return root._parts.length > 0 ? root._parts[root._parts.length - 1] : Player.title
            }
        }

        elide: Text.ElideRight
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        verticalAlignment: Text.AlignVCenter

        Accessible.ignored: true
    }
}
