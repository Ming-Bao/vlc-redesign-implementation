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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util


Widgets.PageLoader {
    id: root

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Music view")
    AccessibleCompat.id: "musicDisplay"

    pageModel: [{
            name: "base",
            default: true,
            component: rootComponent
        }, {
            name: "songs",
            component: songsComponent
        }, {
            name: "artists",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicArtistsDisplay.qml"
        }, {
            name: "albums",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicAlbumsDisplay.qml"
        }, {
            name: "genres" ,
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicGenresDisplay.qml"
        }
    ]

    // the Music root (sidebar variant Figma 858:5001): Add, then a folder tile per sub-page
    Component {
        id: rootComponent

        LibraryRootPage {
            title: qsTr("Music")
            tiles: [
                { glyph: VLCIcons.add, text: qsTr("Add"), add: true },
                { glyph: VLCIcons.topbar_music, text: qsTr("Songs"), page: "songs" },
                { glyph: VLCIcons.album_cover, text: qsTr("Albums"), page: "albums" },
                { glyph: VLCIcons.artist, text: qsTr("Artists"), page: "artists" },
                { glyph: VLCIcons.genre, text: qsTr("Genres"), page: "genres" }
            ]

            onTileActivated: (tile, index, reason) => {
                if (tile.page)
                    History.push([...root.pagePrefix, tile.page], reason)
                else
                    DialogsProvider.addFolderToLibrary()
            }
        }
    }

    // Songs: the audio folder browser; "folder" holds the levels below the root
    Component {
        id: songsComponent

        Widgets.PageLoader {
            pageModel: [{
                    name: "base",
                    default: true,
                    component: songsLevelComponent
                }, {
                    name: "folder",
                    component: songsLevelComponent
                }
            ]
        }
    }

    // mrl and trail come from the History properties; without them it shows the root level
    Component {
        id: songsLevelComponent

        LibraryFolderPage {
            audio: true
            rootCrumbs: [{ title: qsTr("Music"), path: ["music"] }, { title: qsTr("Songs"), path: ["music", "songs"] }]
            folderPath: [...root.pagePrefix, "songs", "folder"]
        }
    }

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    onCurrentItemChanged: {
        if (currentItem) {
            if (currentItem.displayMarginBeginning !== undefined)
                currentItem.displayMarginBeginning = Qt.binding(() => { return root.displayMarginBeginning })

            if (currentItem.displayMarginEnd !== undefined)
                currentItem.displayMarginEnd = Qt.binding(() => { return root.displayMarginEnd })

            if (currentItem.enableBeginningFade !== undefined)
                currentItem.enableBeginningFade = Qt.binding(() => { return root.enableBeginningFade })

            if (currentItem.enableEndFade !== undefined)
                currentItem.enableEndFade = Qt.binding(() => { return root.enableEndFade })
        }
    }
}
