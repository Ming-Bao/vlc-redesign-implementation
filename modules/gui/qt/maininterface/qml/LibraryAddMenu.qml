/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import VLC.Dialogs

// Figma sidebar "Add item": VLC's own add actions
Widgets.FigmaMenu {
    id: root

    // the LibraryPageLoader the menu navigates
    property Item loader
    // the New playlist row opened the dialog: show the Playlists page when it is saved
    property bool _opened: false

    Connections {
        target: DialogsProvider

        function onPlaylistCreated() {
            if (root._opened && !root.loader.isDefaulLoadedForPath(["playlists"]))
                History.push(["playlists"])
            root._opened = false
        }
    }

    rows: (MainCtx.mediaLibraryAvailable ? [
              { text: qsTr("Add folder to library"), run: () => DialogsProvider.addFolderToLibrary() }
          ] : [])
          .concat([{ text: qsTr("Open network stream"), run: () => DialogsProvider.openNetDialog() }])
          .concat(MainCtx.mediaLibraryAvailable ? [
              { text: qsTr("New playlist"), run: () => {
                  _opened = true
                  DialogsProvider.newPlaylist()
              } }
          ] : [])
}

