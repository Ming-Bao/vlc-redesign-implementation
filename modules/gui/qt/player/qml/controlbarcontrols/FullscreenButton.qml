/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Window

import VLC.MainInterface


import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: fullScreenBtn

    // without a video output (music) the window itself goes fullscreen, as the title bar's button did
    readonly property bool _fullscreen: Player.hasVideoOutput ? Player.fullscreen
                                                              : (MainCtx.intfMainWindow.visibility === Window.FullScreen)

    text: _fullscreen ? VLCIcons.defullscreen :VLCIcons.fullscreen
    onClicked: {
        if (Player.hasVideoOutput)
            Player.fullscreen = !Player.fullscreen
        else
            MainCtx.toggleInterfaceFullScreen()
    }
    description: qsTr("fullscreen")

    AccessibleCompat.id: "fullscreenButton"
}
