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
import QtQuick.Templates as T

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Dialogs

// The Playlists root (Figma sidebar variant 858:5374, row 2459:9352): Create playlist, then every playlist
// ponytail: no drag-and-drop of media onto the page and no multi-selection (the Figma shows none)
Widgets.PageExt {
    id: root

    title: qsTr("Playlists")

    // the History path of a playlist's page, set by PlaylistsDisplay (this page's own pagePrefix ends in "all")
    property var listPath: []

    // restored from the navigation history on Back, recorded by the views
    // (not bound to the loader's: it re-applies it on every count change, a search's too, stealing focus)
    property int initialIndex: -1
    // the first focus of a restored page goes to that item
    property bool _restoring: initialIndex >= 0

    readonly property bool _createShown: search.pattern === ""
    readonly property real _titleLine: Math.ceil(titleMetrics.height)

    sortModel: [{ text: qsTr("Alphabetic"), criteria: "title" }]

    itemCount: playlistModel.count

    hasGridListMode: true

    isSearchable: true

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function _open(playlist, index, reason) {
        // recorded here too: a click does not make the card current, and opening index 0 changes nothing
        History.viewProp.initialIndex = index
        History.push(root.listPath, { parentId: playlist.id, title: playlist.name }, reason)
    }

    // the playlist the context menu / Delete key acts on
    property var _targetIds: []

    function _target(index) {
        root._targetIds = [playlistModel.data(playlistModel.index(index, 0), MLPlaylistListModel.PLAYLIST_ID)]
    }

    function _popup(index, globalPos) {
        _target(index)
        contextMenu.popup([playlistModel.index(index, 0)], globalPos)
    }

    function _delete(index) {
        _target(index)
        _deleteTarget()
    }

    function _deleteTarget() {
        const n = root._targetIds.length
        if (DialogsProvider.questionDialog(qsTr("Do you really want to delete the selected playlist?",
                                                "Do you really want to delete the selected playlists?", n),
                                           qsTr("Delete playlist", "Delete playlists", n)))
            playlistModel.deletePlaylists(root._targetIds)
    }

    // the cards eat the arrow keys before the grid sees them: step like ExpandGridView's own Keys
    // handler, or return false to fall through to the view's Navigation (the Create tile, the header)
    function _move(view, from, dx, dy) {
        const to = Helpers.gridStep(from, dx, dy, view.nbItemPerRow, playlistModel.count)
        if (to < 0)
            return false
        view.currentIndex = to
        view.setCurrentItemFocus(dx + dy > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        return true
    }

    // up from the first row: the Create tile
    function _focusHeaderItem(view, reason = Qt.BacktabFocusReason) {
        if (!view?.headerItem?.visible)
            return false
        // enforceFocus: focusing it the first time flips the header Loader's focus, which leaves
        // the tile with OtherFocusReason and no focus ring
        Helpers.enforceFocus(view.headerItem.tile, reason)
        return true
    }

    function _focusBelowCreate(view) {
        if (playlistModel.count > 0)
            view.setCurrentItemFocus(Qt.TabFocusReason)
    }

    // entry and the header's Down: the first playlist (a restored page: its item, once), not Create;
    // Create alone when there is nothing else
    function setCurrentItemFocus(reason) {
        const restoring = root._restoring
        root._restoring = false
        if (playlistModel.count === 0 && !playlistModel.loading) {
            root._focusHeaderItem(loader.currentItem, reason)
            return
        }
        // set before the rows load, so the view focuses that cell as it creates it
        // (an empty library still loading: emptyFocus moves to Create once it has loaded)
        if (loader.currentItem)
            loader.currentItem.currentIndex = !restoring ? 0
                : playlistModel.count > 0 ? Math.min(root.initialIndex, playlistModel.count - 1) : root.initialIndex
        loader.setCurrentItemFocus(reason)
    }

    FontMetrics {
        id: titleMetrics
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
    }

    MLPlaylistListModel {
        id: playlistModel

        ml: MediaLib
        playlistType: MLPlaylistListModel.PLAYLIST_TYPE_ALL

        searchPattern: root.search.pattern
        sortOrder: root.sort.order
        sortCriteria: root.sort.criteria
    }

    // a restored page: put the view on its item once the rows have loaded, once
    // (setting the loader's initialIndex positions the view; -1 again stops later resets)
    Connections {
        id: restoreOnce

        target: playlistModel
        enabled: root.initialIndex >= 0

        function onLoadingChanged() {
            if (playlistModel.loading)
                return
            restoreOnce.enabled = false
            loader.initialIndex = Math.min(root.initialIndex, playlistModel.count - 1)
            loader.initialIndex = -1
        }
    }

    // entered while the library was loading: the view took the focus, but it loaded empty
    Connections {
        id: emptyFocus

        target: playlistModel

        function onLoadingChanged() {
            const view = loader.currentItem
            if (!playlistModel.loading && playlistModel.count === 0 && loader.activeFocus
                    && !(view?.headerItem?.activeFocus ?? false))
                root._focusHeaderItem(view, view?.focusReason ?? Qt.OtherFocusReason)
        }
    }

    PlaylistListContextMenu {
        id: contextMenu

        model: playlistModel
        ctx: MainCtx

        onRequestDeleteSelectedPlaylists: root._deleteTarget()
    }

    MainViewLoader {
        id: loader

        anchors.fill: parent
        focus: true

        model: playlistModel

        grid: gridComponent
        list: listComponent
        emptyLabel: root.search.pattern === "" ? emptyComponent : noResultsComponent

        // entered by a plain focus (the sidebar's Right), not through setCurrentItemFocus: the view
        // holds the focus but no item does. Land on the first playlist, unless the Create tile has it.
        onActiveFocusChanged: if (activeFocus) Qt.callLater(() => {
            const view = loader.currentItem
            if (loader.activeFocus && view && !view.currentItem?.activeFocus && !view.headerItem?.activeFocus)
                root.setCurrentItemFocus(Qt.TabFocusReason)
        })
    }

    Component {
        id: gridComponent

        Widgets.ExpandGridView {
            id: gridView

            readonly property real base: VLCStyle.dp(200, VLCStyle.scale)
            // cells of `base` width stretched to fill the row
            readonly property real _avail: width - contentLeftMargin - contentRightMargin

            nbItemPerRow: Math.max(1, Math.floor((_avail + horizontalSpacing) / (base + horizontalSpacing)))
            cellWidth: Math.floor((_avail + horizontalSpacing) / nbItemPerRow - horizontalSpacing)

            // Figma 970:4079: 20 under the header rule (which already has padding below it), 20 at the bottom
            topMargin: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            model: playlistModel

            Navigation.parentItem: loader
            // up from the first row: the Create tile, then the page header
            Navigation.upAction: () => root._focusHeaderItem(gridView)

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: cellWidth + VLCStyle.dp(30, VLCStyle.scale) + 2 * root._titleLine
            horizontalSpacing: VLCStyle.dp(20, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(40, VLCStyle.scale)

            // collapsed rather than unloaded while searching: the view does not relayout for a removed header
            headerDelegate: createTileComponent

            Component {
                id: createTileComponent

                FocusScope {
                    readonly property Item tile: createTile

                    width: gridView.width
                    visible: root._createShown
                    implicitHeight: visible ? gridView.cellHeight + gridView.verticalSpacing : 0

                    Navigation.parentItem: loader
                    Navigation.downAction: () => root._focusBelowCreate(gridView)

                    HomeSquareCard {
                        id: createTile

                        x: gridView.contentLeftMargin
                        focus: true
                        width: gridView.cellWidth
                        glyph: VLCIcons.add
                        backing: theme.palette?.isDark ? "#1E1E1E" : theme.bg.secondary
                        title: qsTr("Create playlist")

                        Navigation.parentItem: parent

                        onActivated: DialogsProvider.newPlaylist()
                    }
                }
            }

            delegate: FocusScope {
                id: cell

                property Item view
                property var model
                property int index
                property bool selected

                width: gridView.cellWidth
                height: gridView.cellHeight

                Navigation.parentItem: gridView
                Navigation.leftAction: () => root._move(gridView, index, -1, 0)
                Navigation.rightAction: () => root._move(gridView, index, 1, 0)
                Navigation.upAction: () => root._move(gridView, index, 0, -1)
                Navigation.downAction: () => root._move(gridView, index, 0, 1)

                onActiveFocusChanged: if (activeFocus) gridView.currentIndex = index

                HomeSquareCard {
                    focus: true
                    width: cell.width
                    image: cell.model?.thumbnail ?? ""
                    glyph: VLCIcons.playlists
                    title: cell.model?.name ?? ""
                    subtitle: qsTr("%1 track", "%1 tracks", cell.model?.count).arg(cell.model?.count ?? 0)

                    Navigation.parentItem: cell

                    Keys.onDeletePressed: root._delete(cell.index)

                    onActivated: (reason) => root._open(cell.model, cell.index, reason)
                    onMenuRequested: (globalPos) => root._popup(cell.index, globalPos)
                }
            }
        }
    }

    Component {
        id: listComponent

        Widgets.ExpandGridView {
            id: listView

            readonly property real base: VLCStyle.dp(400, VLCStyle.scale)
            // cells of `base` width stretched to fill the row
            readonly property real _avail: width - contentLeftMargin - contentRightMargin

            nbItemPerRow: Math.max(1, Math.floor((_avail + horizontalSpacing) / (base + horizontalSpacing)))
            cellWidth: Math.floor((_avail + horizontalSpacing) / nbItemPerRow - horizontalSpacing)

            topMargin: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            model: playlistModel

            Navigation.parentItem: loader
            // up from the first row: the Create row, then the page header
            Navigation.upAction: () => root._focusHeaderItem(listView)

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: VLCStyle.dp(32, VLCStyle.scale)
            horizontalSpacing: VLCStyle.dp(10, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(10, VLCStyle.scale)

            headerDelegate: createRowComponent

            Component {
                id: createRowComponent

                FocusScope {
                    readonly property Item tile: createRow

                    width: listView.width
                    visible: root._createShown
                    implicitHeight: visible ? listView.cellHeight + listView.verticalSpacing : 0

                    Navigation.parentItem: loader
                    Navigation.downAction: () => root._focusBelowCreate(listView)

                    HomeListRow {
                        id: createRow

                        x: listView.contentLeftMargin
                        focus: true
                        width: listView.cellWidth
                        compact: true
                        glyph: VLCIcons.add
                        text: qsTr("Create playlist")

                        Navigation.parentItem: parent

                        onActivated: DialogsProvider.newPlaylist()
                    }
                }
            }

            delegate: HomeListRow {
                property Item view
                property var model
                property int index
                property bool selected

                width: listView.cellWidth
                compact: true
                showMore: true

                // the Figma row never shows the cover
                glyph: VLCIcons.playlists
                text: model?.name ?? ""

                Navigation.parentItem: listView
                Navigation.leftAction: () => root._move(listView, index, -1, 0)
                Navigation.rightAction: () => root._move(listView, index, 1, 0)
                Navigation.upAction: () => root._move(listView, index, 0, -1)
                Navigation.downAction: () => root._move(listView, index, 0, 1)

                Keys.onDeletePressed: root._delete(index)

                onActiveFocusChanged: if (activeFocus) listView.currentIndex = index

                onActivated: (reason) => root._open(model, index, reason)
                onMenuRequested: (globalPos) => root._popup(index, globalPos)
            }
        }
    }

    Component {
        id: emptyComponent

        Widgets.EmptyLabelHint {
            // under the Create tile / row
            anchors.verticalCenterOffset: VLCStyle.dp(60, VLCStyle.scale)

            text: qsTr("No playlists found")
            hint: qsTr("Right click on a media\nto add it to a playlist")

            cover: VLCStyle.noArtAlbumCover
        }
    }

    Component {
        id: noResultsComponent

        T.Label {
            text: qsTr("No results")
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            color: theme.palette?.isDark ? "#6B6B6B" : theme.fg.secondary
        }
    }
}
