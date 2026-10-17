/******************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Author: Ash <ashutoshv191@gmail.com>
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
 ******************************************************************************/
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

Widgets.PageExt {
    id: root

    property var pagePrefix: [] // behave like a Page

    property var sortModel: [
        { text: qsTr("Alphabetic"), criteria: "title" },
        { text: qsTr("Duration"), criteria: "duration" }
    ]

    title: qsTr("Home")

    hasGridListMode: true

    isSearchable: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    signal seeAllButtonClicked(string name, int reason)

    // see HomeSection.focusX
    property real _focusX: 0

    // folders ranked from the play history (see Helpers.folderEntries)
    property var folderEntries: []

    MLRecentMediaModel {
        id: historyModel

        ml: MediaLib
        limit: 100

        function updateFolders() {
            if (count === 0) {
                root.folderEntries = []
                return
            }
            getDataFlat(Array.from({ length: count }, (_, i) => i), (items) => {
                root.folderEntries = Helpers.folderEntries(items.filter(i => i).map(i => i.mrl.toString()))
            })
        }

        onCountChanged: updateFolders()
        onModelReset: updateFolders()
    }

    function positionContentAtBeginning() {
        contentYBehavior.enabled = true
        flickable.contentY = -flickable.originY
        contentYBehavior.enabled = false
    }

    function setCurrentItemFocus(reason) {
        for (let i = 0; i < sections.count; ++i) {
            const section = sections.itemAt(i)
            if (section.visible) {
                section.setCurrentItemFocus(reason)
                return
            }
        }
    }

    contentItem: Flickable {
        id: flickable

        implicitWidth: sections.implicitWidth
        implicitHeight: sections.implicitHeight

        contentWidth: width
        contentHeight: sections.implicitHeight

        flickableDirection: Flickable.AutoFlickIfNeeded

        boundsBehavior: Flickable.StopAtBounds

        // FIXME: make the media rows positioners consider the flickable margins when adjusting flickable `contentY`.
        bottomMargin: VLCStyle.margin_large

        pixelAligned: (MainCtx.qtVersion() >= MainCtx.qtVersionCheck(6, 2, 5)) // QTBUG-103996
                      && (Screen.pixelDensity >= VLCStyle.highPixelDensityThreshold) // no need for sub-pixel alignment with high pixel density

        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

        // This behavior allows to have similar "smooth" animation
        // that Qt views have with `highlightFollowsCurrentItem`.
        Behavior on contentY {
            id: contentYBehavior

            enabled: false

            // NOTE: Usage of `SmoothedAnimation` is intentional here.
            SmoothedAnimation {
                duration: VLCStyle.duration_veryLong
                easing.type: Easing.InOutSine
            }
        }

        // scroll so that the item is fully shown
        function showItem(item) {
            contentYBehavior.enabled = true
            Helpers.positionFlickableToContainItem(flickable, item)
            contentYBehavior.enabled = false
        }

        property Component implicitFlickableScrollHandler: DefaultFlickableScrollHandler { }

        // NOTE: This property can be set to null to prevent using a scroll handler:
        property FlickableScrollHandler scrollHandler: {
            if (interactive) {
                // JS ownership:
                return implicitFlickableScrollHandler.createObject(null, { target: flickable })
            } else {
                return null
            }
        }

        Component.onCompleted: {
            if (!usingTouch) {
                // Flickable filters child mouse events for flicking (even when
                // the delegate is grabbed). However, this is not a useful
                // feature for non-touch cases, so disable it here and enable
                // it if touch is detected through the hover handler:
                MainCtx.setFiltersChildMouseEvents(flickable, false)
            }
        }

        readonly property bool usingTouch: MainCtx.usingTouch

        onUsingTouchChanged: {
            if (usingTouch)
                MainCtx.setFiltersChildMouseEvents(flickable, true)
            // We do not disable filtering child mouse events
            // because Qt currently has a bug that the flickable
            // jumps when it is enabled again later on.
        }

        Widgets.NavigableCol {
            id: sections

            anchors.left: parent.left
            anchors.right: parent.right

            // Figma: the content column (header included) has 20 px padding. Line up with the
            // header, and count the top 20 from the header rule, which already has padding below.
            leftPadding: root.header?.leftPadding ?? 0
            rightPadding: root.header?.rightPadding ?? 0
            topPadding: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))

            Navigation.parentItem: root
            Navigation.upItem: root.header

            HomeSection {
                id: continueWatching

                width: parent.width

                title: qsTr("Continue Watching")
                cardWidth: VLCStyle.dp(316, VLCStyle.scale)

                model: MLRecentVideoModel {
                    id: continueWatchingModel

                    ml: MediaLib

                    sortCriteria: root.sort.criteria
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    limit: continueWatching.fit
                }

                cardDelegate: Component {
                    HomeVideoCard {
                        contextModel: continueWatchingModel
                    }
                }

                onTitleClicked: (reason) => root.seeAllButtonClicked("continueWatching", reason)
                focusX: root._focusX
                onCardFocused: (x) => root._focusX = x
                onActiveFocusChanged: if (activeFocus) flickable.showItem(this)
            }

            HomeSection {
                id: listenAgain

                width: parent.width

                title: qsTr("Listen Again")
                cardWidth: VLCStyle.dp(200, VLCStyle.scale)

                model: MLRecentAudioModel {
                    id: listenAgainModel

                    ml: MediaLib

                    sortCriteria: root.sort.criteria
                    sortOrder: root.sort.order
                    searchPattern: root.search.pattern

                    limit: listenAgain.fit
                }

                cardDelegate: Component {
                    HomeSquareCard {
                        required property var model
                        required property int index

                        image: model.cover ?? ""
                        glyph: VLCIcons.album_cover
                        title: model.title ?? ""
                        subtitle: model.main_artist ?? ""

                        onActivated: MediaLib.addAndPlay(model.id)
                        onMenuRequested: (globalPos) => listenAgainMenu.popup([listenAgainModel.index(index, 0)], globalPos)
                    }
                }

                MLContextMenu {
                    id: listenAgainMenu

                    model: listenAgainModel
                }

                onTitleClicked: (reason) => root.seeAllButtonClicked("listenAgain", reason)
                focusX: root._focusX
                onCardFocused: (x) => root._focusX = x
                onActiveFocusChanged: if (activeFocus) flickable.showItem(this)
            }

            HomeSection {
                id: folders

                width: parent.width

                title: qsTr("Frequently Visited Folders")
                cardWidth: VLCStyle.dp(200, VLCStyle.scale)

                model: {
                    const pattern = root.search.pattern.toLowerCase()
                    return root.folderEntries.filter(e => e.name.toLowerCase().includes(pattern))
                                             .slice(0, folders.fit)
                }

                cardDelegate: Component {
                    HomeSquareCard {
                        required property var modelData

                        glyph: VLCIcons.folder
                        backing: "#1E1E1E"
                        title: modelData.name

                        onActivated: (reason) => {
                            const tree = MainCtx.folderTree(modelData.mrl)
                            if (tree)
                                History.push(["network", "browse"], { tree: tree }, reason)
                        }
                    }
                }

                onTitleClicked: (reason) => root.seeAllButtonClicked("folders", reason)
                focusX: root._focusX
                onCardFocused: (x) => root._focusX = x
                onActiveFocusChanged: if (activeFocus) flickable.showItem(this)
            }

            HomeSection {
                id: playlists

                width: parent.width

                title: qsTr("Frequently Visited Playlists")
                cardWidth: VLCStyle.dp(200, VLCStyle.scale)

                // ponytail: library order; rank by the plays of a playlist's tracks if that ever matters
                model: MLPlaylistListModel {
                    id: playlistsModel

                    ml: MediaLib
                    playlistType: MLPlaylistListModel.PLAYLIST_TYPE_ALL

                    searchPattern: root.search.pattern

                    limit: playlists.fit
                }

                cardDelegate: Component {
                    HomeSquareCard {
                        required property var model
                        required property int index

                        image: model.thumbnail ?? ""
                        glyph: VLCIcons.playlists
                        title: model.name ?? ""
                        subtitle: qsTr("%1 track", "%1 tracks", model.count).arg(model.count)

                        onActivated: (reason) => History.push(["playlists", "list"], { parentId: model.id, title: model.name }, reason)
                        onMenuRequested: (globalPos) => playlistsMenu.popup([playlistsModel.index(index, 0)], globalPos)
                    }
                }

                MLContextMenu {
                    id: playlistsMenu

                    model: playlistsModel
                }

                onTitleClicked: (reason) => History.push(["playlists"], reason)
                focusX: root._focusX
                onCardFocused: (x) => root._focusX = x
                onActiveFocusChanged: if (activeFocus) flickable.showItem(this)
            }

            HomeSection {
                id: artists

                width: parent.width

                title: qsTr("Frequently Listened Artists")
                cardWidth: VLCStyle.dp(200, VLCStyle.scale)

                model: MLFrequentArtistModel {
                    id: artistsModel

                    ml: MediaLib

                    searchPattern: root.search.pattern

                    limit: artists.fit
                }

                cardDelegate: Component {
                    HomeSquareCard {
                        required property var model
                        required property int index

                        image: model.cover ?? ""
                        glyph: VLCIcons.album_cover
                        title: model.name ?? ""
                        subtitle: qsTr("%1 track", "%1 tracks", model.nb_tracks).arg(model.nb_tracks)

                        onActivated: (reason) => History.push(["music", "artists", "albums"], { artistId: model.id }, reason)
                        onMenuRequested: (globalPos) => artistsMenu.popup([artistsModel.index(index, 0)], globalPos)
                    }
                }

                MLContextMenu {
                    id: artistsMenu

                    model: artistsModel
                }

                onTitleClicked: (reason) => History.push(["music", "artists"], reason)
                focusX: root._focusX
                onCardFocused: (x) => root._focusX = x
                onActiveFocusChanged: if (activeFocus) flickable.showItem(this)
            }
        }
    }
}
