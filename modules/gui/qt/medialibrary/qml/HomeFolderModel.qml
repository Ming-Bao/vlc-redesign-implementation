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
import QtQml

import VLC.MediaLibrary
import VLC.Util

// Folders ranked from the last 100 entries of the play history (see Helpers.folderEntries)
QtObject {
    id: root

    // [{mrl, name}]
    readonly property var entries: _entries
    property var _entries: []

    // the history is loaded and has nothing in it
    readonly property bool empty: !history.loading && history.count === 0

    property int _request: 0

    property MLRecentMediaModel history: MLRecentMediaModel {
        id: history

        ml: MediaLib
        limit: 100

        function update() {
            const request = ++root._request
            if (count === 0) {
                root._entries = []
                return
            }
            getDataFlat(Array.from({ length: count }, (_, i) => i), (items) => {
                if (request === root._request) // a newer update is pending
                    root._entries = Helpers.folderEntries(items.filter(i => i).map(i => i.mrl.toString()))
            })
        }

        onCountChanged: update()
        onModelReset: update()
    }
}
