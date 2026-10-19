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
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// One level of the Videos / Songs folder browser (Figma 970:4028 grid, 970:3792 list):
// the child folders, then the files
// ponytail: no multi-selection or drag (the Figma shows none), wire the views' selectionModel into the cards if needed
Widgets.PageExt {
    id: root

    property bool audio: false
    // the folder of this level, "" for the root
    property string mrl: ""
    // the folders that led here: [{ name, mrl }]
    property var trail: []
    // the fixed leading crumbs: [{ title, path }]
    property var rootCrumbs: []
    // the History path of a child folder level
    property var folderPath: []
    property bool showAdd: false

    // restored from the navigation history on Back / a crumb, recorded by the views
    // (not bound to the loader's: it re-applies it on every count change, a search's too, stealing focus)
    property int initialIndex: -1
    // the first focus of a restored level goes to that item rather than to the Add tile
    property bool _restoring: initialIndex >= 0

    readonly property bool _addShown: showAdd && search.pattern === ""
    readonly property real _titleLine: Math.ceil(titleMetrics.height)

    // the empty label's button, when shown
    property Item _emptyButton: null

    // Songs: the tracks' rows (the old MusicTracksDisplay, less its Disc row the model never sorted by)
    sortModel: root.audio ? [
        { text: qsTr("Title"), criteria: "title" },
        { text: qsTr("Album"), criteria: "album_title" },
        { text: qsTr("Artist"), criteria: "main_artist" },
        { text: qsTr("Duration"), criteria: "duration" },
        { text: qsTr("Track"), criteria: "track_number" }
    ] : [
        { text: qsTr("Alphabetic"), criteria: "title" },
        { text: qsTr("Duration"), criteria: "duration" },
        { text: qsTr("Date added"), criteria: "insertion" }
    ]

    breadcrumbs: rootCrumbs.concat(trail.map((c, i) => ({
        title: c.name, path: folderPath, props: { mrl: c.mrl, trail: trail.slice(0, i + 1) }
    })))

    itemCount: browseModel.count

    hasGridListMode: true

    isSearchable: true

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function _open(folder, index, reason) {
        // recorded here too: a click does not make the card current, and opening index 0 changes nothing
        History.viewProp.initialIndex = index
        History.push(folderPath, {
            mrl: folder.mrl,
            trail: [...trail, { name: folder.title, mrl: folder.mrl }]
        }, reason)
    }

    // the cards eat the arrow keys before the grid sees them: step like ExpandGridView's own Keys
    // handler, or return false to fall through to the view's Navigation (the Add tile, the header)
    function _move(view, from, dx, dy) {
        const to = Helpers.gridStep(from, dx, dy, view.nbItemPerRow, browseModel.count)
        if (to < 0)
            return false
        view.currentIndex = to
        view.setCurrentItemFocus(dx + dy > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        return true
    }

    // up from the first row or from the empty label: the Add tile, if any
    function _focusHeaderItem(view, reason = Qt.BacktabFocusReason) {
        if (!view?.headerItem?.visible)
            return false
        // enforceFocus: focusing it the first time flips the header Loader's focus, which leaves
        // the tile with OtherFocusReason and no focus ring
        Helpers.enforceFocus(view.headerItem.tile, reason)
        return true
    }

    function _focusBelowAdd(view) {
        if (browseModel.count > 0)
            view.setCurrentItemFocus(Qt.TabFocusReason)
        else
            root._emptyButton?.forceActiveFocus(Qt.TabFocusReason)
    }

    // the header's Down and Escape in its search field: the Add tile when shown, else the first item
    // (a restored level: the item restoreOnce puts the view on, once)
    function setCurrentItemFocus(reason) {
        const restoring = root._restoring
        root._restoring = false
        if (!restoring && root._focusHeaderItem(loader.currentItem, reason))
            return
        if (browseModel.count === 0 && !browseModel.loading) {
            root._emptyButton?.forceActiveFocus(reason)
            return
        }
        // set before the rows load, so the view focuses that cell as it creates it
        if (loader.currentItem)
            loader.currentItem.currentIndex = !restoring ? 0
                : browseModel.count > 0 ? Math.min(root.initialIndex, browseModel.count - 1) : root.initialIndex
        loader.setCurrentItemFocus(reason)
    }

    FontMetrics {
        id: titleMetrics
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
    }

    MLFolderBrowseModel {
        id: browseModel

        ml: MediaLib
        audio: root.audio
        folderMrl: root.mrl ?? ""

        searchPattern: root.search.pattern
        sortCriteria: root.sort.criteria
        sortOrder: root.sort.order
    }

    // a restored level: put the view on its item once the rows have loaded, once
    // (setting the loader's initialIndex positions the view; -1 again stops later resets)
    Connections {
        id: restoreOnce

        target: browseModel
        enabled: root.initialIndex >= 0

        function onLoadingChanged() {
            if (browseModel.loading)
                return
            restoreOnce.enabled = false
            loader.initialIndex = Math.min(root.initialIndex, browseModel.count - 1)
            loader.initialIndex = -1
        }
    }

    MLContextMenu {
        id: contextMenu

        model: browseModel
        showPlayAsAudioAction: !root.audio
    }

    MainViewLoader {
        id: loader

        anchors.fill: parent

        model: browseModel

        grid: gridComponent
        list: listComponent
        emptyLabel: (root.mrl === "" && root.search.pattern === "") ? emptyComponent : noResultsComponent
    }

    Component {
        id: gridComponent

        Widgets.ExpandGridView {
            id: gridView

            readonly property real base: VLCStyle.dp(root.audio ? 200 : 316, VLCStyle.scale)
            readonly property real artHeight: root.audio ? cellWidth : Math.round(cellWidth * 9 / 16)
            // cells of `base` width stretched to fill the row
            readonly property real _avail: width - contentLeftMargin - contentRightMargin

            nbItemPerRow: Math.max(1, Math.floor((_avail + horizontalSpacing) / (base + horizontalSpacing)))
            cellWidth: Math.floor((_avail + horizontalSpacing) / nbItemPerRow - horizontalSpacing)

            // Figma 970:4079: 20 under the header rule (which already has padding below it), 20 at the bottom
            topMargin: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            model: browseModel

            Navigation.parentItem: loader
            // up from the first row: the Add tile, then the page header
            Navigation.upAction: () => root._focusHeaderItem(gridView)

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: artHeight + VLCStyle.dp(20, VLCStyle.scale) + root._titleLine
                        + (root.audio ? VLCStyle.dp(10, VLCStyle.scale) + root._titleLine : 0)
            horizontalSpacing: VLCStyle.dp(20, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(40, VLCStyle.scale)

            // collapsed rather than unloaded while searching: the view does not relayout for a removed header
            headerDelegate: root.showAdd ? addTileComponent : null

            Component {
                id: addTileComponent

                FocusScope {
                    readonly property Item tile: addTile

                    width: gridView.width
                    visible: root._addShown
                    implicitHeight: visible ? gridView.cellHeight + gridView.verticalSpacing : 0

                    Navigation.parentItem: loader
                    Navigation.downAction: () => root._focusBelowAdd(gridView)

                    HomeSquareCard {
                        id: addTile

                        x: gridView.contentLeftMargin
                        focus: true
                        width: gridView.cellWidth
                        artHeight: gridView.artHeight
                        glyph: VLCIcons.add
                        backing: theme.palette?.isDark ? "#1E1E1E" : theme.bg.secondary
                        title: qsTr("Add")

                        Navigation.parentItem: parent

                        onActivated: DialogsProvider.addFolderToLibrary()
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

                Loader {
                    focus: true
                    sourceComponent: cell.model?.isFolder ? folderTile
                                                          : root.audio ? audioCard : videoCard
                }

                Component {
                    id: folderTile

                    HomeSquareCard {
                        focus: true
                        width: cell.width
                        artHeight: gridView.artHeight
                        glyph: VLCIcons.folder
                        backing: theme.palette?.isDark ? "#1E1E1E" : theme.bg.secondary
                        title: cell.model.title ?? ""

                        Navigation.parentItem: cell

                        onActivated: (reason) => root._open(cell.model, cell.index, reason)
                    }
                }

                Component {
                    id: videoCard

                    HomeVideoCard {
                        focus: true
                        model: cell.model
                        index: cell.index
                        width: cell.width
                        contextModel: browseModel
                        dimmed: cell.model?.isNew === false
                        playing: Helpers.sameMedia(cell.model?.mrl, Player.url.toString())

                        Navigation.parentItem: cell
                    }
                }

                Component {
                    id: audioCard

                    HomeSquareCard {
                        focus: true
                        width: cell.width
                        image: cell.model.small_cover ?? ""
                        glyph: VLCIcons.album_cover
                        title: cell.model.title ?? ""
                        subtitle: cell.model.main_artist ?? ""
                        playing: Helpers.sameMedia(cell.model?.mrl, Player.url.toString())

                        Navigation.parentItem: cell

                        onActivated: MediaLib.addAndPlay(cell.model.id)
                        onMenuRequested: (globalPos) => contextMenu.popup([browseModel.index(cell.index, 0)], globalPos)
                    }
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

            // Figma 970:4079: 20 under the header rule (which already has padding below it), 20 at the bottom
            topMargin: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            model: browseModel

            Navigation.parentItem: loader
            // up from the first row: the Add tile, then the page header
            Navigation.upAction: () => root._focusHeaderItem(listView)

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: VLCStyle.dp(32, VLCStyle.scale)
            horizontalSpacing: VLCStyle.dp(10, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(10, VLCStyle.scale)

            headerDelegate: root.showAdd ? addRowComponent : null

            Component {
                id: addRowComponent

                FocusScope {
                    readonly property Item tile: addRow

                    width: listView.width
                    visible: root._addShown
                    implicitHeight: visible ? listView.cellHeight + listView.verticalSpacing : 0

                    Navigation.parentItem: loader
                    Navigation.downAction: () => root._focusBelowAdd(listView)

                    HomeListRow {
                        id: addRow

                        x: listView.contentLeftMargin
                        focus: true
                        width: listView.cellWidth
                        compact: true
                        glyph: VLCIcons.add
                        text: qsTr("Add")

                        Navigation.parentItem: parent

                        onActivated: DialogsProvider.addFolderToLibrary()
                    }
                }
            }

            delegate: HomeListRow {
                property Item view
                property var model
                property int index
                property bool selected

                readonly property bool _folder: model?.isFolder ?? false

                width: listView.cellWidth
                compact: true

                image: _folder ? "" : (model?.small_cover ?? "")
                glyph: _folder ? VLCIcons.folder : VLCIcons.album_cover
                progress: !_folder && model?.progress > 0 ? model.progress : -1
                dimmed: !root.audio && model?.isNew === false
                playing: !_folder && Helpers.sameMedia(model?.mrl, Player.url.toString())
                text: (!_folder && root.audio && model?.main_artist) ? model.title + " - " + model.main_artist
                                                                     : (model?.title ?? "")

                Navigation.parentItem: listView
                Navigation.leftAction: () => root._move(listView, index, -1, 0)
                Navigation.rightAction: () => root._move(listView, index, 1, 0)
                Navigation.upAction: () => root._move(listView, index, 0, -1)
                Navigation.downAction: () => root._move(listView, index, 0, 1)

                onActiveFocusChanged: if (activeFocus) listView.currentIndex = index

                onActivated: (reason) => {
                    if (_folder)
                        root._open(model, index, reason)
                    else
                        MediaLib.addAndPlay(model.id)
                }
                onMenuRequested: (globalPos) => {
                    if (!_folder)
                        contextMenu.popup([browseModel.index(index, 0)], globalPos)
                }
            }
        }
    }

    Component {
        id: emptyComponent

        Widgets.EmptyLabelButton {
            id: emptyButton

            coverWidth: VLCStyle.dp(182, VLCStyle.scale)
            coverHeight: VLCStyle.dp(114, VLCStyle.scale)

            focus: true

            text: root.audio ? qsTr("No tracks found\nPlease try adding sources")
                             : qsTr("No video found\nPlease try adding sources")

            cover: root.audio ? VLCStyle.noArtAlbumCover : VLCStyle.noArtVideoCover

            Component.onCompleted: root._emptyButton = emptyButton

            Navigation.parentItem: loader
            Navigation.upAction: () => root._focusHeaderItem(loader.currentItem)
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
