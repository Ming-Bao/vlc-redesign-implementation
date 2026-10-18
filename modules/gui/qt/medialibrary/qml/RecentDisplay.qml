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

// The library's Recent page (sidebar): the playback history, last played first, in the Videos / Songs cards
// ponytail: no multi-selection or drag (the Figma shows none), wire the views' selectionModel into the cards if needed
Widgets.PageExt {
    id: root

    title: qsTr("Recent")

    // restored from the navigation history on Back, recorded by the views
    // (not bound to the loader's: it re-applies it on every count change, a search's too, stealing focus)
    property int initialIndex: -1
    // the first focus of a restored page goes to that item
    property bool _restoring: initialIndex >= 0

    readonly property real _titleLine: Math.ceil(titleMetrics.height)

    // the history keeps its own order
    sortModel: []

    itemCount: recentModel.count

    hasGridListMode: true

    isSearchable: true

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // the cards eat the arrow keys before the grid sees them: step like ExpandGridView's own Keys
    // handler, or return false to fall through to the view's Navigation (the header)
    function _move(view, from, dx, dy) {
        const to = Helpers.gridStep(from, dx, dy, view.nbItemPerRow, recentModel.count)
        if (to < 0)
            return false
        view.currentIndex = to
        view.setCurrentItemFocus(dx + dy > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        return true
    }

    // entry and the header's Down: the first item (a restored page: its item, once)
    function setCurrentItemFocus(reason) {
        const restoring = root._restoring
        root._restoring = false
        // set before the rows load, so the view focuses that cell as it creates it
        if (loader.currentItem)
            loader.currentItem.currentIndex = restoring ? Math.max(0, Math.min(root.initialIndex, recentModel.count - 1)) : 0
        loader.setCurrentItemFocus(reason)
    }

    FontMetrics {
        id: titleMetrics
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
    }

    MLRecentMediaModel {
        id: recentModel

        ml: MediaLib
        searchPattern: root.search.pattern
    }

    // a restored page: put the view on its item once the rows have loaded, once
    // (setting the loader's initialIndex positions the view; -1 again stops later resets)
    Connections {
        id: restoreOnce

        target: recentModel
        enabled: root.initialIndex >= 0

        function onLoadingChanged() {
            if (recentModel.loading)
                return
            restoreOnce.enabled = false
            loader.initialIndex = Math.min(root.initialIndex, recentModel.count - 1)
            loader.initialIndex = -1
        }
    }

    MLContextMenu {
        id: contextMenu

        model: recentModel
        showPlayAsAudioAction: true
    }

    MainViewLoader {
        id: loader

        anchors.fill: parent
        focus: true

        model: recentModel

        grid: gridComponent
        list: listComponent
        emptyLabel: root.search.pattern === "" ? emptyComponent : noResultsComponent

        // entered by a plain focus (the sidebar's Right), not through setCurrentItemFocus: the view
        // holds the focus but no item does. Land on the first item.
        onActiveFocusChanged: if (activeFocus) Qt.callLater(() => {
            const view = loader.currentItem
            if (loader.activeFocus && view && !view.currentItem?.activeFocus)
                root.setCurrentItemFocus(Qt.TabFocusReason)
        })
    }

    Component {
        id: gridComponent

        Widgets.ExpandGridView {
            id: gridView

            readonly property real base: VLCStyle.dp(316, VLCStyle.scale)
            // cells of `base` width stretched to fill the row
            readonly property real _avail: width - contentLeftMargin - contentRightMargin

            nbItemPerRow: Math.max(1, Math.floor((_avail + horizontalSpacing) / (base + horizontalSpacing)))
            cellWidth: Math.floor((_avail + horizontalSpacing) / nbItemPerRow - horizontalSpacing)

            // Figma 970:4079: 20 under the header rule (which already has padding below it), 20 at the bottom
            topMargin: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            model: recentModel

            Navigation.parentItem: loader

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: Math.round(cellWidth * 9 / 16) + VLCStyle.dp(20, VLCStyle.scale) + root._titleLine
            horizontalSpacing: VLCStyle.dp(20, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(40, VLCStyle.scale)

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

                HomeVideoCard {
                    focus: true
                    model: cell.model
                    index: cell.index
                    width: cell.width
                    contextModel: recentModel
                    dimmed: !!cell.model?.isVideo && !cell.model?.isNew
                    glyph: cell.model?.isVideo ? VLCIcons.topbar_video : VLCIcons.topbar_music

                    Navigation.parentItem: cell
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

            model: recentModel

            Navigation.parentItem: loader

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            cellHeight: VLCStyle.dp(32, VLCStyle.scale)
            horizontalSpacing: VLCStyle.dp(10, VLCStyle.scale)
            verticalSpacing: VLCStyle.dp(10, VLCStyle.scale)

            delegate: HomeListRow {
                property Item view
                property var model
                property int index
                property bool selected

                readonly property bool _video: model?.isVideo ?? false

                width: listView.cellWidth
                compact: true

                image: model?.thumbnail ?? ""
                glyph: _video ? VLCIcons.topbar_video : VLCIcons.topbar_music
                progress: model?.progress > 0 ? model.progress : -1
                dimmed: _video && !model?.isNew
                // through a url both ways: Player.url prints decoded ("The Clip"), the mrl encoded ("The%20Clip")
                playing: !!model?.mrl && Qt.resolvedUrl(model.mrl).toString() === Player.url.toString()
                text: (!_video && model?.main_artist) ? model.title + " - " + model.main_artist
                                                      : (model?.title ?? "")

                Navigation.parentItem: listView
                Navigation.leftAction: () => root._move(listView, index, -1, 0)
                Navigation.rightAction: () => root._move(listView, index, 1, 0)
                Navigation.upAction: () => root._move(listView, index, 0, -1)
                Navigation.downAction: () => root._move(listView, index, 0, 1)

                onActiveFocusChanged: if (activeFocus) listView.currentIndex = index

                onActivated: MediaLib.addAndPlay(model.id)
                onMenuRequested: (globalPos) => contextMenu.popup([recentModel.index(index, 0)], globalPos)
            }
        }
    }

    Component {
        id: emptyComponent

        Widgets.EmptyLabelHint {
            text: qsTr("No recent media")
            hint: qsTr("Media you play shows up here")

            cover: VLCStyle.noArtVideoCover
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
