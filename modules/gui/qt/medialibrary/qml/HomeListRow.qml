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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// Home list row (Figma 1106:5633): a 32 px image or glyph and one line of text
T.AbstractButton {
    id: root

    property url image
    // VLCIcons glyph shown when there is no image
    property string glyph
    // 0..1 plays as a mark under the image, -1 hides it
    property real progress: -1

    // mouse -> Qt.MouseFocusReason, Enter/Return -> Qt.OtherFocusReason
    signal activated(int reason)
    signal menuRequested(point globalPos)

    readonly property bool _dark: theme.palette?.isDark ?? false
    readonly property real _art: VLCStyle.dp(32, VLCStyle.scale)

    focusPolicy: Qt.StrongFocus

    width: parent?.width ?? 0
    height: VLCStyle.dp(42, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
        focused: root.visualFocus
    }

    background: Rectangle {
        color: "transparent"
        radius: VLCStyle.dp(4, VLCStyle.scale)
        border.color: root.visualFocus ? theme.visualFocus : "transparent"
    }

    contentItem: Row {
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Rectangle {
            id: art

            anchors.verticalCenter: parent.verticalCenter
            width: root._art
            height: root._art
            radius: VLCStyle.dp(4, VLCStyle.scale)
            // backing under the image like the cards have; without it the ImageExt rows painted blank
            color: root.image.toString() !== "" ? (root._dark ? "#171717" : theme.bg.secondary) : "transparent"

            Widgets.ImageExt {
                anchors.fill: parent
                visible: root.image.toString() !== ""
                source: root.image
                fillMode: Image.PreserveAspectCrop
                radius: VLCStyle.dp(4, VLCStyle.scale)
                sourceSize: Qt.size(width * eDPR, height * eDPR)

                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)
            }

            Widgets.IconLabel {
                anchors.centerIn: parent
                visible: root.image.toString() === ""
                text: root.glyph
                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                color: root._dark ? "#8F8F8F" : theme.fg.secondary
            }

            Rectangle {
                visible: root.progress >= 0
                anchors.bottom: parent.bottom
                width: parent.width * root.progress
                height: VLCStyle.dp(4, VLCStyle.scale)
                color: root._dark ? "#D37918" : theme.accent
            }
        }

        T.Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root._art - parent.spacing
            elide: Text.ElideRight
            text: root.text
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#8F8F8F" : theme.fg.secondary
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => root.menuRequested(eventPoint.globalPosition)
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            event.accepted = true
            root.activated(Qt.OtherFocusReason)
        } else {
            Navigation.defaultKeyAction(event)
        }
    }

    onClicked: root.activated(Qt.MouseFocusReason)
}
