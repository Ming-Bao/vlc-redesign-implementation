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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// The settings window's left column (Figma "Settings - General" 999:5047): a card of grouped category buttons.
// pages: [{name, label, title, icon, group}]
FocusScope {
    id: root

    required property var pages
    property int currentIndex: 0

    signal picked(int index)

    activeFocusOnTab: true
    implicitWidth: VLCStyle.dp(216, VLCStyle.scale)

    // the window's SettingsStyle, so every colour comes from its tokens
    required property SettingsStyle style

    readonly property var _groupNames: ({
        "App": qsTr("App"),
        "Media": qsTr("Media"),
        "System": qsTr("System")
    })

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Settings categories")

    // the focus ring on the selected category only shows for keyboard focus, not after opening or a click
    property bool quietFocus: false
    onActiveFocusChanged: if (!activeFocus) quietFocus = false

    Keys.onPressed: (event) => quietFocus = false

    // keep the selection in view when the window is too short for the whole list
    onCurrentIndexChanged: {
        const it = repeater.itemAt(currentIndex)
        if (!it)
            return
        if (it.y < flick.contentY)
            flick.contentY = it.y
        else if (it.y + it.height > flick.contentY + flick.height)
            flick.contentY = it.y + it.height - flick.height
    }
    Keys.onUpPressed: (event) => {
        quietFocus = false
        if (currentIndex > 0)
            picked(currentIndex - 1)
    }
    Keys.onDownPressed: (event) => {
        quietFocus = false
        if (currentIndex < pages.length - 1)
            picked(currentIndex + 1)
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: VLCStyle.dp(8, VLCStyle.scale)

        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root.style.sidebarBg

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: VLCStyle.dp(6, VLCStyle.scale)

            clip: true
            contentWidth: width
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column

                width: flick.width
                spacing: VLCStyle.dp(8, VLCStyle.scale)

                Repeater {
                    id: repeater
                    model: root.pages

                    delegate: Column {
                        id: entry

                        required property int index
                        required property var modelData

                        readonly property bool selected: index === root.currentIndex

                        width: column.width
                        spacing: column.spacing

                        // group header ("App", "Media", "System") above the first page of each group
                        Widgets.LabelExt {
                            visible: entry.index === 0 || root.pages[entry.index - 1].group !== entry.modelData.group
                            width: parent.width
                            height: visible ? VLCStyle.dp(36, VLCStyle.scale) : 0
                            leftPadding: VLCStyle.dp(10, VLCStyle.scale)
                            verticalAlignment: Text.AlignVCenter
                            text: root._groupNames[entry.modelData.group] ?? entry.modelData.group
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: root.style.label
                            Accessible.ignored: true
                        }

                        Rectangle {
                            id: item

                            width: parent.width
                            height: VLCStyle.dp(40, VLCStyle.scale)
                            radius: VLCStyle.dp(2, VLCStyle.scale)
                            color: entry.selected ? root.style.sidebarSelected
                                                  : (hover.hovered ? root.style.sidebarHover : "transparent")

                            // keyboard focus ring on the selected category
                            border.width: entry.selected && root.activeFocus && !root.quietFocus ? 1 : 0
                            border.color: root.style.accentDim

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: entry.modelData.label
                            Accessible.checked: entry.selected

                            HoverHandler { id: hover }

                            TapHandler {
                                onTapped: {
                                    root.quietFocus = true
                                    root.forceActiveFocus()
                                    root.picked(entry.index)
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: VLCStyle.dp(4, VLCStyle.scale)
                                spacing: VLCStyle.dp(8, VLCStyle.scale)

                                Item {
                                    width: VLCStyle.dp(32, VLCStyle.scale)
                                    height: width

                                    Image {
                                        anchors.centerIn: parent
                                        width: VLCStyle.dp(24, VLCStyle.scale)
                                        height: width
                                        sourceSize: Qt.size(width, height)
                                        source: "qrc:///redesign/settings/" + entry.modelData.icon
                                                + (entry.selected ? "-active" : "") + ".svg"
                                    }
                                }

                                Widgets.LabelExt {
                                    height: parent.height
                                    width: parent.width - x
                                    verticalAlignment: Text.AlignVCenter
                                    text: entry.modelData.label
                                    elide: Text.ElideRight
                                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                                    color: entry.selected ? root.style.labelActive : root.style.value
                                    Accessible.ignored: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
