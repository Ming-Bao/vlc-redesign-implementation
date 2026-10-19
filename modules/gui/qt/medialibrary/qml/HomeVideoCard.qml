/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// Home video card (Figma 6272:13852)
T.AbstractButton {
    id: root

    // roles: id, title, thumbnail, progress
    required property var model
    required property int index
    property var contextModel
    // a watched video: the title greys out
    property bool dimmed: false
    // the current input: accent title and a play mark over the art
    property bool playing: false
    // VLCIcons glyph shown on the backing when there is no thumbnail
    property string glyph

    readonly property bool _dark: theme.palette?.isDark ?? false
    readonly property real _radius: VLCStyle.dp(12, VLCStyle.scale)

    focusPolicy: Qt.StrongFocus
    text: model.title ?? ""

    width: VLCStyle.dp(316, VLCStyle.scale)
    implicitHeight: implicitContentHeight

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
        focused: root.visualFocus
    }

    background: Rectangle {
        x: -VLCStyle.gridItemSelectedBorder
        y: -VLCStyle.gridItemSelectedBorder
        width: root.width + 2 * VLCStyle.gridItemSelectedBorder
        height: root.height + 2 * VLCStyle.gridItemSelectedBorder
        color: "transparent"
        radius: root._radius + VLCStyle.gridItemSelectedBorder
        border.color: root.visualFocus ? theme.visualFocus : "transparent"
    }

    contentItem: Column {
        spacing: VLCStyle.dp(20, VLCStyle.scale)

        Rectangle {
            id: thumb

            width: root.width
            height: Math.round(width * 9 / 16)
            radius: root._radius
            color: root._dark ? "#171717" : theme.bg.secondary

            Widgets.ImageExt {
                anchors.fill: parent
                source: root.model.thumbnail ?? ""
                fillMode: Image.PreserveAspectCrop
                radius: thumb.radius
                sourceSize: Qt.size(width * eDPR, height * eDPR)

                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)
            }

            Widgets.IconLabel {
                anchors.centerIn: parent
                visible: !root.model.thumbnail
                text: root.glyph
                font.pixelSize: VLCStyle.dp(48, VLCStyle.scale)
                color: root._dark ? "#969696" : theme.fg.primary
            }

            // 20 % veil
            Rectangle {
                anchors.fill: parent
                visible: !!root.model.thumbnail
                radius: thumb.radius
                color: Qt.rgba(0, 0, 0, 0.2)
            }

            // progress: the bottom strip of a thumbnail-sized rounded rect, so it follows the corners
            Item {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: thumb.width * (root.model.progress ?? 0)
                height: VLCStyle.dp(4, VLCStyle.scale)
                visible: (root.model.progress ?? 0) > 0
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: thumb.width
                    height: thumb.radius * 2
                    radius: thumb.radius
                    color: root._dark ? "#D37918" : theme.accent
                }
            }

            // the current input, like HomeListRow's mark scaled up
            Rectangle {
                anchors.fill: parent
                visible: root.playing
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.7)

                Widgets.IconLabel {
                    anchors.centerIn: parent
                    text: VLCIcons.play
                    font.pixelSize: VLCStyle.icon_large
                    color: root._dark ? "#D37918" : theme.accent
                }
            }

            // the library grid card's play button
            Widgets.PlayCover {
                anchors.centerIn: parent
                visible: root.hovered || root.visualFocus
                onTapped: MediaLib.addAndPlay(root.model.id)
            }
        }

        T.Label {
            width: root.width
            elide: Text.ElideRight
            text: root.text
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            color: root.playing ? (root._dark ? "#D37918" : theme.accent)
                 : root.dimmed ? (root._dark ? "#6B6B6B" : theme.fg.secondary)
                 : (root._dark ? "#969696" : theme.fg.primary)
        }
    }

    MLContextMenu {
        id: contextMenu

        model: root.contextModel
        // Recent mixes in audio; the video models have no isVideo role
        showPlayAsAudioAction: root.model?.isVideo ?? true
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => contextMenu.popup([root.contextModel.index(root.index, 0)], eventPoint.globalPosition)
    }

    Keys.onMenuPressed: contextMenu.popup([root.contextModel.index(root.index, 0)], root.mapToGlobal(0, root.height))

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            event.accepted = true
            MediaLib.addAndPlay(root.model.id)
        } else {
            Navigation.defaultKeyAction(event)
        }
    }

    onClicked: MediaLib.addAndPlay(root.model.id)
}
