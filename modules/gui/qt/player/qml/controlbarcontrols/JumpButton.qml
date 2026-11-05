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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// the glyphs carry their number: only +-10 is drawn
Widgets.IconToolButton {
    id: root

    property int seconds: 10

    enabled: !paintOnly && Player.seekable

    text: seconds >= 0 ? VLCIcons.jump_fw_10 : VLCIcons.jump_back_10
    onClicked: Player.jumpBySeconds(seconds)
    description: seconds >= 0 ? qsTr("Forward %1 seconds").arg(seconds)
                              : qsTr("Backward %1 seconds").arg(-seconds)

    AccessibleCompat.id: "jumpButton"
}
