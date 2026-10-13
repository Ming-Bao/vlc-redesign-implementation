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
import VLC.Player

// Figma chapters tab: number, name and start time of each chapter; a click jumps there
Item {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark

    // the chapters list, and where keyboard navigation leaves it (forwarded by QueuePanel)
    readonly property alias list: list
    property Item navigationParent: null
    property Item navigationUp: null
    property Item navigationDown: null
    signal navigationCancel()

    Widgets.LabelExt {
        anchors.centerIn: parent
        visible: list.count === 0
        text: qsTr("No chapters")
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._dark ? "#6B6B6B" : theme.fg.secondary
    }

    ListView {
        id: list

        function focusRow() {
            currentIndex = Math.max(0, currentIndex)
            return list
        }

        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        model: Player.chapters
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
        Keys.onReturnPressed: Player.chapters.selectChapter(currentIndex)
        Keys.onEnterPressed: Player.chapters.selectChapter(currentIndex)

        delegate: PanelRow {
            id: chapterRow

            required property int index
            required property var model

            width: ListView.view.width
            leftPadding: VLCStyle.dp(4, VLCStyle.scale)
            rightPadding: VLCStyle.dp(4, VLCStyle.scale)
            text: model.display
            // VLC_TICK_INVALID is 0, so a chapter at the very start would read "--:--"
            trailingText: model.time.valid() ? model.time.formatHMS() : "00:00"
            current: model.checked
            selected: ListView.isCurrentItem && list.activeFocus

            leading: Widgets.LabelExt {
                width: VLCStyle.dp(34, VLCStyle.scale)
                text: chapterRow.index + 1
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                font.weight: Font.Medium
                color: chapterRow.colorContext.accent
            }

            onClicked: Player.chapters.selectChapter(index)
        }
    }
}
