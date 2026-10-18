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

// Home square card (Figma 6272:13898, folder variant 6284:13980)
T.AbstractButton {
    id: root

    property url image
    // VLCIcons glyph shown when there is no image
    property string glyph
    property color backing: theme.palette?.isDark ? "#171717" : theme.bg.secondary
    property string title
    property string subtitle
    // the art box is width × artHeight (a 16:9 folder tile on a video level)
    property real artHeight: width
    // the Playlists page's multi-selection: a Ctrl/Shift+click emits selectClicked instead of activated
    property bool selectable: false
    property bool selected: false
    // a drag hovers the item and it takes the drop
    property bool dropTarget: false
    property int _pressModifiers: Qt.NoModifier

    // mouse -> Qt.MouseFocusReason, Enter/Return -> Qt.OtherFocusReason
    signal activated(int reason)
    signal menuRequested(point globalPos)
    signal selectClicked(int modifiers)

    readonly property bool _dark: theme.palette?.isDark ?? false

    focusPolicy: Qt.StrongFocus
    text: title

    width: VLCStyle.dp(200, VLCStyle.scale)
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
        radius: VLCStyle.dp(12, VLCStyle.scale) + VLCStyle.gridItemSelectedBorder
        border.color: root.visualFocus ? theme.visualFocus
                    : root.selected || root.dropTarget ? (root._dark ? "#D37918" : theme.accent) : "transparent"
    }

    contentItem: Column {
        spacing: VLCStyle.dp(20, VLCStyle.scale)

        Rectangle {
            width: root.width
            height: root.artHeight
            radius: VLCStyle.dp(12, VLCStyle.scale)
            color: root.backing

            Widgets.ImageExt {
                anchors.fill: parent
                visible: root.image.toString() !== ""
                source: root.image
                fillMode: Image.PreserveAspectCrop
                radius: parent.radius
                sourceSize: Qt.size(width * eDPR, height * eDPR)

                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)
            }

            Widgets.IconLabel {
                anchors.centerIn: parent
                visible: root.image.toString() === ""
                text: root.glyph
                font.pixelSize: VLCStyle.dp(48, VLCStyle.scale)
                color: root._dark ? "#969696" : theme.fg.primary
            }

            // selected: the tint shows under the focus ring too
            Rectangle {
                anchors.fill: parent
                visible: root.selected
                radius: parent.radius
                color: Qt.alpha(root._dark ? "#D37918" : theme.accent, 0.15)
            }
        }

        Column {
            width: root.width
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            T.Label {
                width: parent.width
                elide: Text.ElideRight
                text: root.title
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._dark ? "#969696" : theme.fg.primary
            }

            T.Label {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: root.subtitle
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._dark ? "#6B6B6B" : theme.fg.secondary
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => root.menuRequested(eventPoint.globalPosition)
    }

    Keys.onMenuPressed: root.menuRequested(root.mapToGlobal(0, root.height))

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            event.accepted = true
            root.activated(Qt.OtherFocusReason)
        } else {
            Navigation.defaultKeyAction(event)
        }
    }

    // a Ctrl/Shift press selects, before the press focuses the item (so the view's current item is still the
    // Shift range's start), and its click activates nothing. Passive: the button still gets the press.
    TapHandler {
        enabled: root.selectable
        onPressedChanged: {
            if (!pressed)
                return
            root._pressModifiers = point.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)
            if (root._pressModifiers)
                root.selectClicked(root._pressModifiers)
        }
    }
    onClicked: if (!root.selectable || !root._pressModifiers) root.activated(Qt.MouseFocusReason)
}
