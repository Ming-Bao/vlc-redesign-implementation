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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.PlayerControls
import VLC.Menus
import VLC.Dialogs

// Figma queue tab: count and length with sort/repeat/shuffle/remove/add, then the queue
ColumnLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark

    // the queue list, and where keyboard navigation leaves it (wired by the player)
    readonly property alias list: list
    property Item navigationParent: null
    property Item navigationUp: null
    property Item navigationDown: null
    signal navigationCancel()

    spacing: 0

    PlaylistListModel {
        id: queueModel
        playlist: MainPlaylistController.playlist
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(68, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: qsTr("%1 items - %2").arg(queueModel.count).arg(queueModel.duration.formatLong())
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Widgets.SortControl {
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Sort")
            enabled: MainPlaylistController.count > 1
            checked: MainPlaylistController.sortKey !== PlaylistController.SORT_KEY_NONE
            popupAbove: false
            model: MainPlaylistController.sortKeyTitleList
            sortKey: MainPlaylistController.sortKey
            sortOrder: (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC)
                       ? Qt.DescendingOrder : Qt.AscendingOrder
            onSortSelected: key => { MainPlaylistController.sortKey = key }
            onSortOrderSelected: type => {
                MainPlaylistController.sortOrder = (type === Qt.DescendingOrder)
                        ? PlaylistController.SORT_ORDER_DESC : PlaylistController.SORT_ORDER_ASC
                MainPlaylistController.sort()
            }
        }

        LoopButton { font.pixelSize: VLCStyle.icon_normal }

        RandomButton { font.pixelSize: VLCStyle.icon_normal }

        Widgets.IconToolButton {
            text: VLCIcons.remove
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Remove from the queue")
            enabled: list.currentIndex >= 0
            onClicked: list.removeCurrent()
        }

        Widgets.IconToolButton {
            text: VLCIcons.add
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Add to the queue")
            onClicked: addMenu.popup(mapToGlobal(0, height), [qsTr("Add File..."), qsTr("Add Folder...")])

            StringListMenu {
                id: addMenu
                ctx: MainCtx
                onSelected: (index) => {
                    if (index === 0)
                        DialogsProvider.simpleOpenDialog(false)
                    else
                        DialogsProvider.PLAppendDir()
                }
            }
        }
    }

    ListView {
        id: list

        // PlayerPanel.onOpened focuses this: the cursor starts on the playing item
        function focusRow() {
            if (currentIndex < 0)
                currentIndex = Math.max(0, MainPlaylistController.currentIndex)
            positionViewAtIndex(currentIndex, ListView.Contain)
            return list
        }

        function removeCurrent() {
            if (currentIndex >= 0)
                queueModel.removeItems([currentIndex])
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: queueModel
        currentIndex: -1
        spacing: VLCStyle.dp(12, VLCStyle.scale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Navigation.parentItem: root.navigationParent
        Navigation.upItem: root.navigationUp
        Navigation.downItem: root.navigationDown
        Navigation.leftAction: () => root.navigationCancel()
        Navigation.cancelAction: () => root.navigationCancel()

        // navigating into the list puts the cursor on a row
        onActiveFocusChanged: if (activeFocus) focusRow()

        // the list moves its cursor first; keys it leaves (Up on the first row, Escape...) navigate out
        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
        Keys.onReturnPressed: MainPlaylistController.goTo(currentIndex, true)
        Keys.onEnterPressed: MainPlaylistController.goTo(currentIndex, true)
        Keys.onDeletePressed: removeCurrent()

        delegate: PanelRow {
            id: queueRow

            required property int index
            required property var model

            width: ListView.view.width
            text: model.title
            trailingText: model.duration.formatShort()
            current: model.isCurrent
            selected: ListView.isCurrentItem

            leading: Widgets.IconLabel {
                id: handle

                width: VLCStyle.dp(32, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: VLCIcons.drag_handle
                font.pixelSize: VLCStyle.icon_normal
                color: queueRow._dark ? "#8F8F8F" : queueRow.colorContext.fg.secondary

                // the row lands where the pointer is on release; the cursor tint shows the spot meanwhile
                DragHandler {
                    id: dragHandler

                    target: null
                    xAxis.enabled: false

                    function targetIndex() {
                        const p = list.mapFromItem(null, dragHandler.centroid.scenePosition)
                        const x = VLCStyle.dp(10, VLCStyle.scale)
                        // a gap between rows belongs to the row below it
                        let i = list.indexAt(x, p.y + list.contentY)
                        if (i < 0)
                            i = list.indexAt(x, p.y + list.contentY + list.spacing)
                        if (i >= 0)
                            return i
                        return p.y < 0 ? 0 : list.count - 1
                    }

                    onCentroidChanged: if (active) list.currentIndex = targetIndex()
                    onActiveChanged: {
                        if (active)
                            return
                        const to = targetIndex()
                        // the move is applied later by the core: the cursor follows the dragged item through it
                        list.currentIndex = queueRow.index
                        if (to !== queueRow.index)
                            queueModel.moveItemsPre([queueRow.index], to > queueRow.index ? to + 1 : to)
                    }
                }
            }

            onClicked: list.currentIndex = index
            onDoubleClicked: MainPlaylistController.goTo(index, true)
        }
    }
}
