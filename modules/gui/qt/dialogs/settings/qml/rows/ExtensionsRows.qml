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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// The Extensions page's add-ons block: the list of installed Lua extensions (name and version; the description on
// hover), a search field, and Find more extensions / Add / Remove. Remove is enabled for an extension in the user's
// folder only. Selection is by row of the bridge's model (the search only hides rows).
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null

    property int selected: -1
    property string selectedFile: ""    // captured at click time: row numbers change on any reload
    property string selectedTitle: ""
    property int hoverRow: -1
    property string hoverSummary: ""
    property real hoverY: 0
    property string query: ""
    readonly property bool removable: selected >= 0 && selectedFile.length > 0 && SettingsBridge.canRemoveExtension(selected)

    spacing: VLCStyle.dp(8, VLCStyle.scale)

    // a search that hides the selected row clears the selection
    onQueryChanged: if (selected >= 0 && !_matches(selectedTitle)) selected = -1

    function _matches(title) {
        // plain substring, whatever characters the search has
        return query.length === 0 || String(title).toLowerCase().indexOf(query.toLowerCase()) !== -1
    }

    Rectangle {
        width: root.width
        height: VLCStyle.dp(190, VLCStyle.scale)
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root.style ? root.style.field : "transparent"
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: root.style ? root.style.face : "transparent"

        // one tooltip for the list, not one per delegate: a delegate is not yet under the row when its tooltip takes its palette
        Widgets.ToolTipExt {
            colorContext.palette: VLCStyle.palette
            x: VLCStyle.dp(10, VLCStyle.scale)
            y: root.hoverY + VLCStyle.dp(4, VLCStyle.scale)
            z: 1
            visible: root.hoverRow >= 0 && root.hoverSummary.length > 0
            text: root.hoverSummary
            width: Math.min(implicitWidth, VLCStyle.dp(360, VLCStyle.scale))
        }

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: VLCStyle.dp(4, VLCStyle.scale)
            clip: true
            model: SettingsBridge.extensions
            // any reload (Add, Remove) renumbers the rows
            Connections {
                target: list.model
                function onModelReset() { root.selected = -1 }
            }
            Accessible.role: Accessible.List
            Accessible.name: root.row.label

            delegate: T.ItemDelegate {
                id: item

                required property int index
                required property string title
                required property string summary
                required property string version

                readonly property bool matches: root._matches(title)
                readonly property bool isSelected: root.selected === index

                width: ListView.view.width
                height: matches ? VLCStyle.dp(36, VLCStyle.scale) : 0
                visible: matches
                onClicked: {
                    root.selected = index
                    root.selectedFile = SettingsBridge.extensionFile(index)
                    root.selectedTitle = title
                }
                Accessible.name: title

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: item.isSelected ? root.style.accentBg : item.hovered ? root.style.face : "transparent"
                    border.width: item.visualFocus ? VLCStyle.focus_border : 0
                    border.color: root.style.accent
                }
                contentItem: Item {
                    Widgets.LabelExt {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                        anchors.right: ver.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.title
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: item.isSelected ? root.style.accent : root.style.rowLabel
                    }
                    Widgets.LabelExt {
                        id: ver
                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.version
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root.style.label
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        root.hoverRow = index
                        root.hoverSummary = summary
                        root.hoverY = y - list.contentY + height
                    } else if (root.hoverRow === index) {
                        root.hoverRow = -1
                    }
                }
            }
        }
    }

    Item {
        width: root.width
        height: VLCStyle.dp(36, VLCStyle.scale)

        T.TextField {
            id: search

            width: VLCStyle.dp(210, VLCStyle.scale)
            height: parent.height
            leftPadding: VLCStyle.dp(12, VLCStyle.scale)
            rightPadding: VLCStyle.dp(12, VLCStyle.scale)
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.value : "transparent"
            selectByMouse: true
            onTextChanged: root.query = text
            Accessible.name: qsTr("Search")

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root.style ? root.style.field : "transparent"
                border.width: VLCStyle.dp(2, VLCStyle.scale)
                border.color: search.activeFocus ? root.style.accent : root.style ? root.style.face : "transparent"

                Widgets.LabelExt {   // the placeholder: a Templates TextField draws none
                    anchors.left: parent.left
                    anchors.leftMargin: search.leftPadding
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text.length === 0
                    text: qsTr("Search")
                    font.pixelSize: search.font.pixelSize
                    color: root.style ? root.style.placeholder : "transparent"
                }
            }
        }

        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            component FaceButton: T.Button {
                id: btn

                height: VLCStyle.dp(32, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                opacity: enabled ? 1.0 : root.style.disabledOpacity
                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root.style.face
                    border.width: btn.visualFocus ? VLCStyle.focus_border : 0
                    border.color: root.style.accent
                }
                contentItem: Widgets.LabelExt {
                    text: btn.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    font.weight: Font.DemiBold
                    color: root.style.rowLabel
                }
            }

            FaceButton {
                width: VLCStyle.dp(185, VLCStyle.scale)
                text: qsTr("Find more extensions")
                onClicked: DialogsProvider.pluginDialog()
            }

            FaceButton {
                width: VLCStyle.dp(100, VLCStyle.scale)
                text: qsTr("Add")
                onClicked: {
                    const u = SettingsBridge.pickLuaFile()
                    if (u.toString().length)
                        SettingsBridge.addExtension(u)
                }
            }

            FaceButton {
                width: VLCStyle.dp(100, VLCStyle.scale)
                text: qsTr("Remove")
                enabled: root.removable
                onClicked: {
                    const file = root.selectedFile
                    root.Window.window.ask(qsTr("Remove the extension \"%1\"?").arg(root.selectedTitle),
                                           () => SettingsBridge.removeExtensionFile(file), qsTr("Remove"))
                }
            }
        }
    }
}
