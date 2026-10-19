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
import VLC.Util

// The library pages (Home, Videos, Music, ...) driven by the global History.
// Used by MainDisplay and by the player side panel.
Widgets.PageLoader {
    id: root

    signal viewLoaded()

    pageModel: [
        {
            name: "home",
            url: MainCtx.mediaLibraryAvailable ?
                 "qrc:///qt/qml/VLC/MediaLibrary/HomeDisplay.qml" :
                 "qrc:///qt/qml/VLC/MainInterface/NoMedialibHome.qml"
        }, {
            name: "video",
            url: "qrc:///qt/qml/VLC/MediaLibrary/VideoDisplay.qml"
        }, {
            name: "music",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicDisplay.qml"
        }, {
            name: "network",
            url: "qrc:///qt/qml/VLC/Network/BrowseDisplay.qml"
        }, {
            name: "playlists",
            url: "qrc:///qt/qml/VLC/MediaLibrary/PlaylistsDisplay.qml"
        }, {
            name: "recent",
            url: "qrc:///qt/qml/VLC/MediaLibrary/RecentDisplay.qml"
        }, {
            name: "discover",
            url: "qrc:///qt/qml/VLC/Network/DiscoverDisplay.qml"
        }, {
            name: "mlsettings",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MLFoldersSettings.qml"
        }
    ]

    function loadCurrentHistoryView(focusReason) {
        if (loadView(History.viewPath, History.viewProp, focusReason))
            viewLoaded()
        contextSaver.restore(History.viewPath)
    }

    // Scroll to the top when already on that section, else navigate to it
    function openSection(uri) {
        if (isDefaulLoadedForPath([...uri]) ||
            (!!uri.length && History.exactMatch(History.viewPath, uri))) {
            positionContentAtBeginning()
            return
        }

        History.push(uri)
    }

    Component.onCompleted: {
        if (History.previousEmpty) {
            History.update(["home"])
        }
        loadCurrentHistoryView(Qt.OtherFocusReason)
    }

    ModelSortSettingHandler {
        id: contextSaver
    }

    Connections {
        target: MainCtx.sort

        function onCriteriaChanged(criteria) {
            contextSaver.save(History.viewPath)
        }

        function onOrderChanged(order) {
            contextSaver.save(History.viewPath)
        }
    }

    Connections {
        target: History
        function onNavigate(focusReason) {
            root.loadCurrentHistoryView(focusReason)
        }
    }
}
