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
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Util

// Open Network Stream (Figma 6216:13614): a list of links and an optional name. With a name the links are saved and
// the Network page opens on them, without one they are played. Single instance, opened by Dialogs.qml.
DialogCard {
    id: root

    readonly property var links: SavedStreams.parseLinks(urlField.text)
    readonly property string streamName: nameField.text.trim()

    title: qsTr("Open Network Stream")
    figmaWidth: 1048
    figmaHeight: 631
    modal: true
    saveEnabled: links.length > 0
    saveText: streamName ? qsTr("Save") : qsTr("Open")

    onCancelled: close()
    onSaved: {
        if (!saveEnabled)
            return
        if (streamName && SavedStreams.exists(streamName))
            ask(qsTr("A saved stream named \"%1\" already exists. Replace it?").arg(streamName), _commit, qsTr("Replace"))
        else
            _commit()
    }
    onVisibleChanged: {
        if (!visible)
            return
        urlField.clear()
        nameField.clear()
        urlField.forceActiveFocus()
    }

    function _commit() {
        if (streamName) {
            const entry = SavedStreams.save(streamName, links)
            if (!entry.mrl)
                return
            close()
            const tree = MainCtx.folderTree(entry.mrl, entry.name)
            if (tree)
                History.push(["network", "browse"], { tree: tree })
        } else {
            close()
            if (MainCtx.mediaLibraryAvailable) {
                MediaLib.addAndPlay(links[0])
                for (const l of links.slice(1))
                    MediaLib.addToPlaylist(l)
            } else {
                MainPlaylistController.append(links, true)
            }
        }
    }

    // a title and a hint below it; the optional part of a title is dimmed
    component Head: Column {
        property string text
        property string optional
        property string hint

        spacing: VLCStyle.dp(5, VLCStyle.scale)

        Row {
            spacing: VLCStyle.dp(5, VLCStyle.scale)

            Widgets.LabelExt {
                text: parent.parent.text
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._s.sectionTitle
            }
            Widgets.LabelExt {
                visible: text
                text: parent.parent.optional
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._s.label
            }
        }
        Widgets.LabelExt {
            text: parent.hint
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.label
        }
    }

    // the Figma input: field colour, 2 px border (accent when focused), the placeholder in the dim colour
    component Box: Rectangle {
        property Item input
        property string placeholder

        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: input.activeFocus ? root._s.accent : root._s.face

        Widgets.LabelExt {
            x: input.leftPadding + parent.border.width
            y: input.topPadding + parent.border.width
            visible: input.text.length === 0
            text: parent.placeholder
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.placeholder
        }
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(22, VLCStyle.scale)
        anchors.bottomMargin: VLCStyle.dp(22, VLCStyle.scale)
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(20, VLCStyle.scale)

        Head {
            text: qsTr("Network URL")
            hint: qsTr("You can enter multiple links to load.")
        }

        Box {
            width: parent.width
            height: VLCStyle.dp(194, VLCStyle.scale)
            input: urlField
            placeholder: qsTr("e.g., https://www.example.com/stream.avi")

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: parent.border.width
                clip: true
                contentHeight: urlField.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                T.ScrollBar.vertical: Widgets.ScrollBarExt {}

                T.TextArea.flickable: T.TextArea {
                    id: urlField

                    leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                    rightPadding: VLCStyle.dp(18, VLCStyle.scale)
                    topPadding: VLCStyle.dp(8, VLCStyle.scale)
                    bottomPadding: VLCStyle.dp(8, VLCStyle.scale)
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._s.value
                    selectionColor: root._s.accent
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Network URL")
                    // Tab leaves the box, it does not type a tab
                    KeyNavigation.priority: KeyNavigation.BeforeItem
                    KeyNavigation.tab: nameField
                }
            }
        }

        Rectangle {
            width: parent.width
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: root._s.divider
        }

        Head {
            text: qsTr("Playlist Name")
            optional: qsTr("(optional)")
            hint: qsTr("The playlist will be saved and displayed with this title.")
        }

        Box {
            width: parent.width
            height: VLCStyle.dp(37, VLCStyle.scale)
            input: nameField
            placeholder: qsTr("e.g., Favorite TV Channels")

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
                Accessible.name: qsTr("Playlist Name")
            }
        }
    }
}
