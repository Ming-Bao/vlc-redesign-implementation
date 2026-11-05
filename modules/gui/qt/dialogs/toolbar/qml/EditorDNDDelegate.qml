/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQml.Models


import VLC.Player
import VLC.Style

T.Control {
    id: control

    padding: VLCStyle.dp(1, VLCStyle.scale)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    readonly property int controlId: model.id
    property Item dndView: null

    readonly property bool dragActive: contentItem.target.Drag.active

    property alias containsMouse: mouseArea.containsMouse
    property alias pressed: mouseArea.pressed

    ListView.delayRemove: dragActive

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Item
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        cursorShape: pressed ? Qt.DragMoveCursor : Qt.OpenHandCursor

        drag.target: dragItem

        drag.smoothed: false

        hoverEnabled: true

        property point grabPoint

        onPressed: (mouse) => { grabPoint = Qt.point(mouse.x, mouse.y) }

        drag.onActiveChanged: {
            if (drag.active) {
                PlayerControlbarControls.customizeDragging = true
                drag.target.Drag.start()
            } else {
                control.visible = false
                const action = drag.target.Drag.drop()
                if (action === Qt.IgnoreAction)
                    control.visible = true
                PlayerControlbarControls.customizeDragging = false
            }
        }

    }

    DropArea {
        id: dropArea

        anchors.fill: parent

        // a drop lands on the nearer side of this control
        readonly property bool after: drag.x > width / 2

        onEntered: (drag) => {
            drag.accepted = !control.pressed && dndView.accepts(drag.source)
        }

        onDropped: (drop) => {
            let destIndex = parent.DelegateModel.itemsIndex + (after ? 1 : 0)

            if ((drop.source.dndView === dndView)
                    && (drop.source.DelegateModel.itemsIndex < destIndex))
                --destIndex

            dndView.dropEvent(drop, destIndex)
        }
    }

    Rectangle {
        x: dropArea.after ? parent.width - width : 0
        anchors.verticalCenter: parent.verticalCenter

        z: 1

        implicitWidth: VLCStyle.dp(2, VLCStyle.scale)
        implicitHeight: VLCStyle.icon_medium

        visible: dropArea.containsDrag
        color: theme.accent
    }

    background: DashedBox { }

    contentItem: Item {
        implicitHeight: loader.implicitHeight
        implicitWidth: loader.implicitWidth

        readonly property Item target: dragItem

        // what the pointer moves
        Item {
            id: dragItem

            // over everything in the window, the bars and the palette included
            parent: Drag.active ? control.Window.contentItem : control.contentItem
            z: Drag.active ? 1000 : 0

            anchors.fill: (parent === control.contentItem) ? parent : undefined
            width: control.contentItem.width
            height: control.contentItem.height

            Drag.source: control
            // the pointer picks the zone, not the corner of the control dragged under it
            Drag.hotSpot: mouseArea.grabPoint

            Loader {
                id: loader

                anchors.fill: parent

                source: PlayerControlbarControls.control(model.id).source

                onLoaded: {
                    PlayerControlbarControls.applyProps(item, model.id)
                    if (typeof item.compactStyle === "boolean")
                        item.compactStyle = dndView.compactStyle
                    item.paintOnly = true
                    item.enabled = false
                    // a label's implicit width follows the width it was first given, 0 here, while it elides
                    if (item.elide !== undefined)
                        item.elide = Text.ElideNone
                }
            }
        }
    }
}
