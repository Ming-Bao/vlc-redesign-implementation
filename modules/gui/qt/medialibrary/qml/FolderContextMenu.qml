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
import VLC.Dialogs
import VLC.Util

// @brief - the library folder menu (Figma 2139:8935): Home's folders, the folder levels' folders
QtObject {
    id: root

    // the menu acts on the videos directly in the folder (not its subfolders), as the library has them
    function popup(folderMrl, globalPos) {
        _mrl = folderMrl
        _pos = globalPos
        _pending = true
        if (_files.folderMrl !== folderMrl)
            _files.folderMrl = folderMrl // reloads, then loading turns false
        else if (!_files.loading)
            _fetch()
    }

    property string _mrl
    property point _pos
    property bool _pending: false
    property int _request: 0
    property var _videoIds: []

    function _fetch() {
        if (!_pending)
            return
        _pending = false
        const request = ++_request
        const show = (ids) => {
            if (request !== _request) // another popup meanwhile
                return
            _videoIds = ids
            _menu.popup([], _pos)
        }
        if (_files.count === 0)
            show([])
        else
            // its folder rows come first and are skipped
            _files.getDataFlat(Array.from({ length: _files.count }, (_, i) => i),
                               (items) => show(items.filter(i => i && !i.isFolder).map(i => i.id)))
    }

    readonly property MLFolderBrowseModel _files: MLFolderBrowseModel {
        ml: MediaLib
        audio: false
        sortCriteria: "title"

        onLoadingChanged: if (!loading) root._fetch()
    }

    readonly property NativeMenu _menu: NativeMenu {
        actions: [{
                "text": qsTr("Play all videos"),
                "icon": "play",
                "enabled": root._videoIds.length > 0,
                "action": (dataList) => MediaLib.addAndPlay(dataList[0].videoIds)
            }, {
                "text": qsTr("Add all videos to the queue"),
                "icon": "add-to-queue",
                "enabled": root._videoIds.length > 0,
                "action": (dataList) => MediaLib.addToPlaylist(dataList[0].videoIds)
            }, {
                "text": qsTr("Add File"),
                "icon": "add",
                "action": (dataList) => {
                    // as urls, which the queue names by their file name
                    for (const mrl of DialogsProvider.pickMedia(qsTr("Add File"), dataList[0].mrl))
                        MediaLib.addToPlaylist(Qt.url(mrl))
                }
            }, {
                "text": qsTr("Add Folder"),
                "icon": "add-folder",
                "action": (dataList) => {
                    const url = DialogsProvider.pickFolder(qsTr("Add Folder"), dataList[0].mrl)
                    if (url.toString() !== "")
                        MediaLib.addToPlaylist(url)
                }
            }, {
                "text": qsTr("Resync"),
                "icon": "resync",
                "action": (dataList) => MediaLib.reloadFolder(dataList[0].mrl)
            }
        ]

        onRequestData: (requestID) => setData(requestID, [{ mrl: root._mrl, videoIds: root._videoIds }])
    }
}
