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
import VLC.MediaLibrary
import VLC.Player
import VLC.Util

// toggles the library favorite flag of the playing media; off for media the library does not hold
Widgets.IconToolButton {
    id: root

    property bool _inLibrary: false
    property bool _favorite: false

    enabled: !paintOnly && _inLibrary

    text: VLCIcons.favorite
    description: qsTr("Favorite")
    checked: _favorite

    AccessibleCompat.id: "favoriteButton"

    function refresh() {
        _inLibrary = false
        _favorite = false
        if (!MainCtx.mediaLibraryAvailable || !Player.isStarted)
            return
        const url = Player.url
        MediaLib.mediaFavorite(url, (inLibrary, favorite) => {
            // the media may have changed while the library answered
            if (url !== Player.url)
                return
            _inLibrary = inLibrary
            _favorite = favorite
        })
    }

    onClicked: {
        _favorite = !_favorite
        MediaLib.setMediaFavorite(Player.url, _favorite)
    }

    Component.onCompleted: refresh()

    Connections {
        target: Player
        function onInputChanged() { root.refresh() }
    }
}
