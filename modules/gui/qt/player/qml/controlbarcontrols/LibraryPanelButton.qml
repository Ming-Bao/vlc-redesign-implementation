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

// shows the library side panel over the player (closed each time the player opens)
Widgets.IconToolButton {
    // true when the host (LocalTopbar) handles the click itself
    property bool hostHandles: false

    font.pixelSize: VLCStyle.icon_banner
    text: VLCIcons.panel_left
    description: qsTr("Show navigation menu")
    width: VLCStyle.bannerButton_width
    height: VLCStyle.bannerButton_height
    checked: PlayerControlbarControls.libraryPanelOpen
    onClicked: {
        if (!hostHandles)
            PlayerControlbarControls.libraryPanelOpen = !PlayerControlbarControls.libraryPanelOpen
    }

    AccessibleCompat.id: "sidebarToggleButton"
}
