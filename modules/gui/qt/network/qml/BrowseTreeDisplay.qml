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


import VLC.Util
import VLC.Widgets as Widgets
import VLC.MainInterface
import VLC.Style
import VLC.Network

Widgets.PageExt {

    id: root

    title: model.name

    property alias model: loader.model
    property var headerPath: model.path ?? []

    property var contextMenu

    readonly property var currentIndex: loader.currentItem?.currentIndex ?? -1

    signal browse(var tree, int reason)

    isSearchable: loader.isSearchable

    // Network ▸ source ▸ folder…, each crumb browses back to its node
    breadcrumbs: [{ title: qsTr("Network"), path: ["network"] }].concat(
        headerPath.map((node) => ({ title: node.display, path: root.pagePrefix, props: { tree: node.tree } })))

    // the old header's "Add to / Remove from media library" button
    headerMenuRows: (root.model?.canBeIndexed ?? false) ? [{
        text: root.model.indexed ? qsTr("Remove from media library") : qsTr("Add to media library"),
        run: () => { root.model.indexed = !root.model.indexed }
    }] : []

    MainViewLoader {
        id: loader

        anchors.fill: parent

        isSearchable: true

        sortModel: [
            { text: qsTr("Alphabetic"), criteria: "name"},
            { text: qsTr("Url"), criteria: "mrl" },
            { text: qsTr("File size"), criteria: "fileSizeRaw64" },
            { text: qsTr("File modified"), criteria: "fileModified" }
        ]

        grid: gridComponent
        list: tableComponent

        emptyLabel: emptyLabelComponent

        Navigation.cancelAction: function() {
            History.previous(Qt.BacktabFocusReason)
        }

        function playSelected() {
            model.addAndPlay(loader.selectionModel.selectedIndexes)
        }

        function playAt(index) {
            model.addAndPlay(index)
        }

        function _actionAtIndex(index) {
            if ( loader.selectionModel.selectedIndexes.length > 1 ) {
                playSelected()
            } else {
                const data = model.getDataAt(index)
                if (data.type === NetworkMediaModel.TYPE_DIRECTORY
                        || data.type === NetworkMediaModel.TYPE_NODE
                        || data.type === NetworkMediaModel.TYPE_PLAYLIST)  {
                    browse(data.tree, Qt.TabFocusReason)
                } else {
                    playAt(index)
                }
            }
        }

        Widgets.DragItem {
            id: networkDragItem

            indexes: loader.selectionModel.selectedIndexes

            defaultText:  qsTr("Unknown Share")

            coverProvider: function(index, data) {
                const fallbackImage = SVGColorImage.colorize(data.artworkFallback)
                    .background(networkDragItem.colorContext.bg.secondary)
                    .color1(networkDragItem.colorContext.fg.primary)
                    .accent(networkDragItem.colorContext.accent)
                    .uri()

                return {
                    artwork: data.artwork,
                    fallback: fallbackImage,
                    // FIXME: `call(null, index)` is to prevent the following warning in list view mode
                    //        where the view is a C++ type:
                    //         > Calling C++ methods with 'this' objects different from the one they
                    //         > were retrieved from is broken, due to historical reasons. The original
                    //         > object is used as 'this' object. You can allow the given 'this' object
                    //         > to be used by setting 'pragma NativeMethodBehavior: AcceptThisObject'
                    textureProvider: root.currentItem?.itemAtIndex.call(null, index)?.artworkTextureProvider ?? null
                }
            }

            onRequestData: (indexes, resolve, reject) => {
                resolve(
                    indexes.map(x => model.getDataAt(x.row))
                )
            }

            onRequestInputItems: (indexes, data, resolve, reject) => {
                model.getItemsForIndexes(indexes, resolve)
            }
        }

        Component{
            id: gridComponent

            Widgets.ExpandGridItemView {
                id: gridView

                basePictureWidth: VLCStyle.gridCover_network_width
                basePictureHeight: VLCStyle.gridCover_network_height
                subtitleHeight: 0

                maxNbItemPerRow: 12

                selectionModel: loader.selectionModel
                model: root.model

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd

                delegate: NetworkGridItem {
                    id: delegateGrid

                    width: gridView.cellWidth;
                    height: gridView.cellHeight;

                    pictureWidth: gridView.maxPictureWidth
                    pictureHeight: gridView.maxPictureHeight

                    subtitle: ""
                    dragItem: networkDragItem

                    onPlayClicked: playAt(index)
                    onItemClicked : (modifier, select) => {
                        gridView.leftClickOnItem(modifier, index, select)
                    }

                    onItemDoubleClicked: {
                        if (model.type === NetworkMediaModel.TYPE_NODE
                                || model.type === NetworkMediaModel.TYPE_DIRECTORY
                                || model.type === NetworkMediaModel.TYPE_PLAYLIST)
                            browse(model.tree, Qt.MouseFocusReason)
                        else
                            playAt(index)
                    }

                    onContextMenuButtonClicked: (_, globalMousePos) => {
                        gridView.rightClickOnItem(index)
                        contextMenu.popup(loader.selectionModel.selectedIndexes, globalMousePos)
                    }
                }

                onActionAtIndex: (index) => { _actionAtIndex(index) }

                Navigation.parentItem: root
                Navigation.upItem: root.header
            }
        }

        Component{
            id: tableComponent

            Widgets.TableViewExt {
                id: tableView

                property Component thumbnailColumn: NetworkThumbnailItem {
                    onPlayClicked: index => playAt(index)
                }

                property var _modelSmall: [{
                    weight: 1,

                    model: ({
                        criteria: "name",

                        title: "name",

                        subCriterias: [ "mrl" ],

                        text: qsTr("Name"),

                        headerDelegate: tableColumns.titleHeaderDelegate,
                        colDelegate: thumbnailColumn
                    })
                }]

                property var _modelMedium: [{
                    size: 1,

                    model: {
                        criteria: "thumbnail",

                        text: qsTr("Cover"),

                        isSortable: false,

                        headerDelegate: tableColumns.titleHeaderDelegate,
                        colDelegate: thumbnailColumn
                    }
                }, {
                    weight: 1,

                    model: {
                        criteria: "name",

                        text: qsTr("Name")
                    }
                }, {
                    weight: 1,

                    model: {
                        criteria: "mrl",

                        text: qsTr("Url"),

                        showContextButton: true
                    }
                }, {
                    size: 1,

                    model: {
                        criteria: "duration",

                        text: qsTr("Duration"),

                        showContextButton: true,
                        headerDelegate: tableColumns.timeHeaderDelegate,
                        colDelegate: tableColumns.timeColDelegate
                    }
                }]

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd
                fadingEdge.enableBeginningFade: root.enableBeginningFade
                fadingEdge.enableEndFade: root.enableEndFade

                dragItem: networkDragItem

                sortModel: (_availableRowWidth < VLCStyle.colWidth(4)) ? _modelSmall
                                                                       : _modelMedium

                model: root.model

                selectionModel: loader.selectionModel
                focus: true

                Navigation.parentItem: root
                Navigation.upItem: root.header

                rowHeight: VLCStyle.tableCoverRow_height

                rowContextMenu: root.contextMenu

                onActionForSelection: (selection) => _actionAtIndex(selection[0].row)
                onItemDoubleClicked: (index, model) => _actionAtIndex(index)

                onRightClick: (_,_,globalMousePos) => {
                    root.contextMenu.popup(loader.selectionModel.selectedIndexes, globalMousePos)
                }

                Widgets.TableColumns {
                    id: tableColumns

                    titleCover_width: VLCStyle.listAlbumCover_width
                    titleCover_height: VLCStyle.listAlbumCover_height

                    showTitleText: tableView.sortModel === tableView._modelSmall
                }
            }
        }

        Component {
            id: emptyLabelComponent

            Widgets.EmptyLabelButton {
                id: emptyLabel

                background: Rectangle {
                    // NOTE: This is necessary because MainViewLoader may position this indicator over the shown header when height is small.
                    border.color: emptyLabel.colorContext.border
                    border.pixelAligned: (radius < Number.EPSILON)
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: emptyLabel.colorContext.bg.primary
                    opacity: 0.8
                }

                // FIXME: find better cover
                cover: VLCStyle.noArtVideoCover
                coverWidth : VLCStyle.dp(182, VLCStyle.scale)
                coverHeight: VLCStyle.dp(114, VLCStyle.scale)

                text: qsTr("Nothing to see here, go back.")

                button.iconTxt: VLCIcons.back
                button.text: qsTr("Back")
                button.enabled: !History.previousEmpty
                button.width: button.implicitWidth

                function onNavigate(reason) {
                    History.previous(reason)
                }

                Navigation.parentItem: root
                Navigation.upItem: root.header
            }
        }
    }
}
