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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Dialogs

// New Playlist (Figma 6259:14954): a title, a cover and the files to start with. Single instance, opened by MainInterface.qml.
DialogCard {
    id: root

    property var files: []
    property url cover

    readonly property string playlistName: nameField.text.trim()

    title: qsTr("New Playlist")
    figmaWidth: 713
    figmaHeight: 589
    modal: true
    saveEnabled: playlistName !== ""

    onCancelled: close()
    onSaved: {
        if (!saveEnabled)
            return
        playlists.createFromFiles(playlistName, files.map(f => Qt.url(f)), cover)
        close()
    }
    onVisibleChanged: {
        if (!visible)
            return
        nameField.clear()
        files = []
        cover = ""
        nameField.forceActiveFocus()
    }

    function _addFiles(urls) {
        files = files.concat(urls.filter(u => !files.includes(u)))
    }

    function _pickCover() {
        const url = DialogsProvider.pickImage(qsTr("Select a thumbnail"))
        if (url.toString() !== "")
            cover = url
    }

    function _pickFiles() {
        _addFiles(DialogsProvider.pickMedia(qsTr("Select Files"), ""))
    }

    function _fileName(url) {
        return decodeURIComponent(url.substring(url.lastIndexOf("/") + 1))
    }

    MLPlaylistListModel {
        id: playlists
        ml: MediaLib
    }

    // a title and a hint below it
    component Head: Column {
        property string text
        property string hint

        spacing: VLCStyle.dp(5, VLCStyle.scale)

        Widgets.LabelExt {
            text: parent.text
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            color: root._s.sectionTitle
        }
        Widgets.LabelExt {
            text: parent.hint
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.label
        }
    }

    // the Figma 30 square "+" button (84 wide in the drop box)
    component PlusButton: Rectangle {
        implicitWidth: VLCStyle.dp(30, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(30, VLCStyle.scale)
        radius: VLCStyle.dp(5, VLCStyle.scale)
        color: root.colorContext.palette.isDark ? "#161616" : root.colorContext.palette.tokens.bgA5   // fixed colour: off-token dark value (FG/B1 as a surface)

        Widgets.IconLabel {
            anchors.centerIn: parent
            text: VLCIcons.add
            font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
            color: root._s.value
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

        Head {
            y: VLCStyle.dp(26, VLCStyle.scale)
            text: qsTr("Playlist Details")
            hint: qsTr("The playlist will be saved and displayed with this title and thumbnail.")
        }

        Rectangle {
            x: VLCStyle.dp(2, VLCStyle.scale)
            y: VLCStyle.dp(104, VLCStyle.scale)
            width: VLCStyle.dp(541, VLCStyle.scale)
            height: VLCStyle.dp(37, VLCStyle.scale)

            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.field
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: nameField.activeFocus ? root._s.accent : root._s.face

            Widgets.LabelExt {
                x: nameField.leftPadding + parent.border.width
                y: nameField.topPadding + parent.border.width
                visible: nameField.text.length === 0
                text: qsTr("e.g., Favorite Videos")
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.placeholder
            }

            T.TextField {
                id: nameField

                anchors.fill: parent
                anchors.margins: parent.border.width
                leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                rightPadding: VLCStyle.dp(18, VLCStyle.scale)
                topPadding: VLCStyle.dp(8, VLCStyle.scale)
                bottomPadding: VLCStyle.dp(8, VLCStyle.scale)
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.value
                selectionColor: root._s.accent
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: qsTr("Playlist Details")
                KeyNavigation.tab: coverWell
            }
        }

        // the thumbnail: the picked image cropped to fill
        Rectangle {
            id: coverWell

            anchors.right: parent.right
            y: VLCStyle.dp(31, VLCStyle.scale)
            width: VLCStyle.dp(112, VLCStyle.scale)
            height: width

            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.field
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: activeFocus ? root._s.accent : root._s.face
            activeFocusOnTab: true
            KeyNavigation.tab: dropBox

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Select a thumbnail")
            Accessible.onPressAction: root._pickCover()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root._pickCover()
                    event.accepted = true
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: parent.border.width
                visible: root.cover.toString() !== ""
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
            }

            PlusButton {
                anchors.centerIn: parent
            }

            TapHandler { onTapped: { coverWell.forceActiveFocus(); root._pickCover() } }
        }

        Rectangle {
            y: VLCStyle.dp(161, VLCStyle.scale)
            width: parent.width
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: root._s.divider
        }

        Head {
            y: VLCStyle.dp(185, VLCStyle.scale)
            text: qsTr("Select Files")
            hint: qsTr("These files will be added to the playlist.")
        }

        Item {
            id: dropBox

            y: VLCStyle.dp(260, VLCStyle.scale)
            width: parent.width
            height: VLCStyle.dp(186, VLCStyle.scale)
            activeFocusOnTab: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Drag files into the box or click here to select files.")
            Accessible.onPressAction: root._pickFiles()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root._pickFiles()
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._s.field
            }

            // the 2 px dashed border
            Canvas {
                id: dashes

                readonly property color stroke: drop.containsDrag || dropBox.activeFocus ? root._s.accent
                                               : root.colorContext.palette.isDark ? "#2D2D2D" : root.colorContext.palette.tokens.dividerBright   // fixed colour: off-token dark value

                anchors.fill: parent
                onStrokeChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const lw = VLCStyle.dp(2, VLCStyle.scale)
                    const r = VLCStyle.dp(6, VLCStyle.scale)
                    ctx.reset()
                    ctx.strokeStyle = stroke
                    ctx.lineWidth = lw
                    ctx.setLineDash([lw * 3, lw * 2])
                    ctx.beginPath()
                    ctx.roundedRect(lw / 2, lw / 2, width - lw, height - lw, r, r)
                    ctx.stroke()
                }
            }

            DropArea {
                id: drop

                anchors.fill: parent
                onEntered: (drag) => drag.accepted = drag.hasUrls
                onDropped: (drop) => {
                    if (drop.hasUrls)
                        root._addFiles(DialogsProvider.expandFolders(drop.urls))
                }
            }

            TapHandler {
                onTapped: { dropBox.forceActiveFocus(); root._pickFiles() }
            }

            // empty: the hint and the + button
            Column {
                anchors.centerIn: parent
                visible: root.files.length === 0
                spacing: VLCStyle.dp(14, VLCStyle.scale)

                Widgets.LabelExt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Drag files into the box or click here to select files.")
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._s.placeholder
                }

                PlusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: VLCStyle.dp(84, VLCStyle.scale)
                }
            }

            // filled: a row per file, each with a remove button, and the + button below
            ListView {
                anchors.fill: parent
                anchors.margins: VLCStyle.dp(12, VLCStyle.scale)
                anchors.bottomMargin: VLCStyle.dp(50, VLCStyle.scale)
                visible: root.files.length > 0
                clip: true
                model: root.files
                boundsBehavior: Flickable.StopAtBounds
                T.ScrollBar.vertical: Widgets.ScrollBarExt {}

                delegate: Item {
                    required property string modelData
                    required property int index

                    width: ListView.view.width
                    height: VLCStyle.dp(28, VLCStyle.scale)

                    Widgets.LabelExt {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(6, VLCStyle.scale)
                        anchors.right: removeButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._fileName(modelData)
                        elide: Text.ElideMiddle
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root._s.sectionTitle
                    }

                    Rectangle {
                        id: removeButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.dp(24, VLCStyle.scale)
                        height: width
                        radius: VLCStyle.dp(5, VLCStyle.scale)
                        color: removeHover.hovered ? root._s.face : "transparent"

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Remove")
                        Accessible.onPressAction: removeTap.tapped(null)

                        HoverHandler { id: removeHover }
                        TapHandler {
                            id: removeTap
                            onTapped: root.files = root.files.filter((_, i) => i !== index)
                        }

                        Image {
                            anchors.centerIn: parent
                            width: VLCStyle.dp(20, VLCStyle.scale)
                            height: width
                            sourceSize: Qt.size(width, height)
                            source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/settings/close.svg")
                        }
                    }
                }
            }

            PlusButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: VLCStyle.dp(12, VLCStyle.scale)
                visible: root.files.length > 0
                width: VLCStyle.dp(84, VLCStyle.scale)
            }
        }
    }
}
