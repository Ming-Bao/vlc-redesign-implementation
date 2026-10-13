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

// Figma bookmarks tab: count with remove/add, then the current media's bookmarks
ColumnLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark
    // MLBookmarkModel is only registered with a media library: create it by name, so that without
    // one the page still loads and keeps only its header
    readonly property var _model: MainCtx.mediaLibraryAvailable
        ? Qt.createQmlObject("import VLC.MediaLibrary; import VLC.Player; MLBookmarkModel { player: Player; ml: MediaLib }",
                             root, "BookmarksPage.model")
        : null

    // the bookmarks list, and where keyboard navigation leaves it (forwarded by QueuePanel)
    readonly property alias list: list
    property Item navigationParent: null
    property Item navigationUp: null
    property Item navigationDown: null
    signal navigationCancel()

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(64, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: qsTr("%1 Bookmarks").arg(list.count)
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Widgets.IconToolButton {
            text: VLCIcons.remove
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Remove bookmark")
            enabled: list.currentIndex >= 0
            onClicked: list.removeCurrent()
        }

        Widgets.IconToolButton {
            text: VLCIcons.add
            font.pixelSize: VLCStyle.icon_normal
            description: qsTr("Add bookmark")
            enabled: root._model?.canAdd ?? false
            onClicked: root._model.add()
        }
    }

    ListView {
        id: list

        // PlayerPanel.onOpened focuses this: the cursor starts on the first bookmark
        function focusRow() {
            if (currentIndex < 0 && count > 0)
                currentIndex = 0
            return list
        }

        function removeCurrent() {
            if (currentIndex >= 0)
                root._model.remove([root._model.index(currentIndex, 0)])
        }

        function seekCurrent() {
            if (currentIndex >= 0)
                root._model.select(root._model.index(currentIndex, 0))
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: root._model
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
        // a model reset (add, remove, media change) keeps the cursor: keep it on an existing row
        onCountChanged: if (currentIndex >= count) currentIndex = count - 1

        // the list moves its cursor first; keys it leaves (Up on the first row, Escape...) navigate out
        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
        Keys.onReturnPressed: seekCurrent()
        Keys.onEnterPressed: seekCurrent()
        Keys.onDeletePressed: removeCurrent()

        delegate: PanelRow {
            required property int index
            required property var model

            width: ListView.view.width
            text: model.name
            trailingText: model.time
            selected: ListView.isCurrentItem

            onClicked: list.currentIndex = index
            onDoubleClicked: { list.currentIndex = index; list.seekCurrent() }
        }
    }
}
