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
            displayText: qsTr("Artists"),
            name: "artists",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicArtistsDisplay.qml"
        }, {
            displayText: qsTr("Albums"),
            name: "albums",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicAlbumsDisplay.qml"
        }, {
            displayText: qsTr("Genres"),
            name: "genres" ,
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicGenresDisplay.qml"
        }
    ]

    // the Music root (sidebar variant Figma 858:5001): Add, then a folder tile per sub-page
    Component {
        id: rootComponent

        Widgets.PageExt {
            id: musicRoot

            readonly property var _tiles: [
                { glyph: VLCIcons.add, text: qsTr("Add") },
                { glyph: VLCIcons.topbar_music, text: qsTr("Songs"), page: "songs" },
                { glyph: VLCIcons.album_cover, text: qsTr("Albums"), page: "albums" },
                { glyph: VLCIcons.artist, text: qsTr("Artists"), page: "artists" },
                { glyph: VLCIcons.genre, text: qsTr("Genres"), page: "genres" }
            ]
            readonly property real _gap: VLCStyle.dp(20, VLCStyle.scale)
            readonly property int _columns: MainCtx.gridView
                ? Math.max(1, Math.floor((tiles.width - tiles.leftPadding - tiles.rightPadding + _gap) / (VLCStyle.dp(200, VLCStyle.scale) + _gap)))
                : 1

            title: qsTr("Music")
            isSearchable: false
            itemCount: 4

            focus: true

            readonly property ColorContext colorContext: ColorContext {
                id: theme
                colorSet: ColorContext.View
            }

            function _activate(tile, reason) {
                if (tile.page)
                    History.push([...root.pagePrefix, tile.page], reason)
                else
                    DialogsProvider.addFolderToLibrary()
            }

            // the cards eat the arrow keys: step through the tiles, or return false to fall
            // through to the body's Navigation (up: the header)
            function _move(from, dx, dy) {
                const to = Helpers.gridStep(from, dx, dy, _columns, repeater.count)
                if (to < 0)
                    return false
                repeater.itemAt(to).forceActiveFocus(dx + dy > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                return true
            }

            function setCurrentItemFocus(reason) {
                repeater.itemAt(0)?.forceActiveFocus(reason)
            }

            FocusScope {
                id: body

                anchors.fill: parent
                focus: true

                Flow {
                    id: tiles

                    anchors.fill: parent
                    leftPadding: musicRoot.header?.leftPadding ?? 0
                    rightPadding: musicRoot.header?.rightPadding ?? 0
                    // Figma 970:4079: 20 under the header rule, which already has padding below it
                    topPadding: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (musicRoot.header?.bottomPadding ?? 0))
                    flow: MainCtx.gridView ? Flow.LeftToRight : Flow.TopToBottom
                    spacing: MainCtx.gridView ? musicRoot._gap : VLCStyle.dp(10, VLCStyle.scale)

                    Repeater {
                        id: repeater

                        model: musicRoot._tiles

                        delegate: MainCtx.gridView ? tileCard : tileRow
                    }
                }
            }

            Component {
                id: tileCard

                HomeSquareCard {
                    required property var modelData
                    required property int index

                    focus: index === 0
                    glyph: modelData.glyph
                    backing: theme.palette?.isDark ? "#1E1E1E" : theme.bg.secondary
                    title: modelData.text

                    Navigation.parentItem: body
                    Navigation.leftAction: () => musicRoot._move(index, -1, 0)
                    Navigation.rightAction: () => musicRoot._move(index, 1, 0)
                    Navigation.upAction: () => musicRoot._move(index, 0, -1)
                    Navigation.downAction: () => musicRoot._move(index, 0, 1)

                    onActivated: (reason) => musicRoot._activate(modelData, reason)
                }
            }

            Component {
                id: tileRow

                HomeListRow {
                    required property var modelData
                    required property int index

                    focus: index === 0
                    // ponytail: list rows take the Videos/Music list's 400 base, not the full width
                    width: VLCStyle.dp(400, VLCStyle.scale)
                    compact: true
                    glyph: modelData.glyph
                    text: modelData.text

                    Navigation.parentItem: body
                    Navigation.leftAction: () => musicRoot._move(index, -1, 0)
                    Navigation.rightAction: () => musicRoot._move(index, 1, 0)
                    Navigation.upAction: () => musicRoot._move(index, 0, -1)
                    Navigation.downAction: () => musicRoot._move(index, 0, 1)

                    onActivated: (reason) => musicRoot._activate(modelData, reason)
                }
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
