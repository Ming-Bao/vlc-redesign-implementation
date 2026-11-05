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
import VLC.Style
import VLC.Player

// Figma player title bar: the folder of the playing media, also the way back to the library
Widgets.ButtonExt {
    id: root

    property bool paintOnly: false

    // media without a folder (streams, discs) get a generic label instead of no chip
    readonly property string folderName: {
        const url = Player.url.toString()
        const parts = url.startsWith("file:") ? decodeURIComponent(url).split("/") : []
        const folder = (parts.length > 2) ? parts[parts.length - 2] : ""
        return folder.length > 0 ? folder : qsTr("Library")
    }

    enabled: !paintOnly

    // the divider between the title bar's buttons and the chip, drawn in the chip's own width
    leftInset: dividerRect.width + VLCStyle.margin_xsmall
    leftPadding: padding + leftInset

    Rectangle {
        id: dividerRect

        anchors.verticalCenter: parent.verticalCenter
        width: VLCStyle.dp(1, VLCStyle.scale)
        height: VLCStyle.dp(20, VLCStyle.scale)
        color: windowTheme.separator
    }

    // the chip is text on the window, not a standard button
    readonly property ColorContext windowContext: ColorContext {
        id: windowTheme
        colorSet: ColorContext.Window
    }

    iconTxt: VLCIcons.folder
    text: folderName
    color: windowTheme.fg.secondary
    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)

    Accessible.description: qsTr("Back to the library")

    // open the folder of the playing media in the browser, or the library for other media
    onClicked: {
        PlayerControlbarControls.leavePlayer()

        const folder = MainCtx.folderMRL(Player.url)
        const tree = MainCtx.folderTree(folder)
        if (tree)
            History.push(["network", "browse"], { tree: tree })
    }
}
