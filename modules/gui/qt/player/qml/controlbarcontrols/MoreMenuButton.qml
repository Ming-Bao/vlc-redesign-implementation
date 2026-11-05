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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Style
import VLC.Player
import VLC.Util

// the "..." menu of the title bar
Widgets.IconToolButton {
    id: root

    signal requestLockUnlockAutoHide(bool lock)
    // the menu's Discover entry; leaves the player for the Discover page unless the surroundings handle it
    signal discoverRequested()

    // true when the host (LocalTopbar) handles discoverRequested itself
    property bool hostHandles: false

    visible: paintOnly || !MainCtx.hasToolbarMenu
    font.pixelSize: VLCStyle.icon_banner
    text: VLCIcons.ellipsis
    description: qsTr("Menu")
    width: VLCStyle.bannerButton_width
    height: VLCStyle.bannerButton_height
    checked: contextMenu.shown

    AccessibleCompat.id: "moreMenuButton"

    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

    onDiscoverRequested: {
        if (hostHandles)
            return
        PlayerControlbarControls.leavePlayer()
        History.push(["discover"])
    }

    function forceUnlock() {
        contextMenu.close()
    }

    Menus.QmlGlobalMenu {
        id: contextMenu
        ctx: MainCtx
        flat: true

        onDiscoverRequested: root.discoverRequested()

        onAboutToShow: root.requestLockUnlockAutoHide(true)
        onAboutToHide: root.requestLockUnlockAutoHide(false)
    }
}
