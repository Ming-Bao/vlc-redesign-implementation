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
    // the Videos/Music list row (Figma 970:3792): 32 high, a #303030 square thumbnail
    property bool compact: false
    // a watched video: greyed text
    property bool dimmed: false
    // the current input: accent text and a play mark over the thumbnail
    property bool playing: false
    // a trailing "…" button, shown while hovered or focused: it emits menuRequested (Figma 2459:9352)
    property bool showMore: false
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
    readonly property real _moreSize: VLCStyle.dp(24, VLCStyle.scale)
    readonly property real _art: VLCStyle.dp(32, VLCStyle.scale)
    readonly property real _artRadius: VLCStyle.dp(compact ? 2 : 4, VLCStyle.scale)

    focusPolicy: Qt.StrongFocus

    width: parent?.width ?? 0
    height: VLCStyle.dp(compact ? 32 : 42, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
        focused: root.visualFocus
    }

    background: Rectangle {
        // the tint shows under the focus ring too
        color: root.selected ? Qt.alpha(root._dark ? "#D37918" : theme.accent, 0.15) : "transparent"
        radius: VLCStyle.dp(4, VLCStyle.scale)
        border.color: root.visualFocus ? theme.visualFocus
                    : root.selected || root.dropTarget ? (root._dark ? "#D37918" : theme.accent) : "transparent"
    }

    contentItem: Row {
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Rectangle {
            id: art

            anchors.verticalCenter: parent.verticalCenter
            width: root._art
            height: root._art
            radius: root._artRadius
            // backing under the image like the cards have; without it the ImageExt rows painted blank
            color: root.image.toString() === "" ? "transparent"
                                                : root._dark ? (root.compact ? "#303030" : "#171717") : theme.bg.secondary

            Widgets.ImageExt {
                anchors.fill: parent
                visible: root.image.toString() !== ""
                source: root.image
                fillMode: Image.PreserveAspectCrop
                radius: root._artRadius
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
                // compact: 3 px, ending 4 px before the thumbnail's right edge
                width: (parent.width - (root.compact ? VLCStyle.dp(4, VLCStyle.scale) : 0)) * root.progress
                height: VLCStyle.dp(root.compact ? 3 : 4, VLCStyle.scale)
                color: root._dark ? "#D37918" : theme.accent
            }

            Rectangle {
                anchors.fill: parent
                visible: root.playing
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.7)

                Widgets.IconLabel {
                    anchors.centerIn: parent
                    text: VLCIcons.play
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    color: root._dark ? "#D37918" : theme.accent
                }
            }
        }

        T.Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root._art - parent.spacing - (root.showMore ? root._moreSize + parent.spacing : 0)
            elide: Text.ElideRight
            text: root.text
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.playing ? (root._dark ? "#D37918" : theme.accent)
                 : root.dimmed ? (root._dark ? "#6B6B6B" : theme.fg.secondary)
                 : root.compact ? (root._dark ? (root.showMore && root.hovered ? "#C6C6C6" : "#969696") : theme.fg.primary)
                 : (root._dark ? "#8F8F8F" : theme.fg.secondary)
        }
    }

    // not a tab stop: the menu key already opens the menu
    MouseArea {
        visible: root.showMore && (root.hovered || root.visualFocus)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root._moreSize
        height: root._moreSize

        onClicked: root.menuRequested(mapToGlobal(0, height))

        Widgets.IconLabel {
            anchors.centerIn: parent
            text: VLCIcons.more
            font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
            color: root._dark ? "#8F8F8F" : theme.fg.secondary
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
