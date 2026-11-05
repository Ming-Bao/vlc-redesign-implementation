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
import QtQml.Models

import VLC.Style
import VLC.Util
import VLC.Player
import VLC.PlayerControls

// One zone of a player bar in Customize Player: its controls, and the free space beside them, dashed and droppable
Item {
    id: root

    property alias model: view.model
    property alias count: view.count
    property alias spacing: view.spacing

    // where the controls sit in the zone (the free space is the rest)
    property int alignment: Qt.AlignLeft
    property bool compactStyle: false
    // the free space is drawn at rest (the bottom row's are, Figma 2160:6564; else only during a drag, Figma 2160:7437)
    property bool dashFreeSpace: true
    property bool drawFreeSpace: true
    property real emptyWidth: VLCStyle.dp(40, VLCStyle.scale)
    // the seekbar may be dropped here
    property bool acceptsSeekbar: false

    readonly property real listStart: view.x
    readonly property real listEnd: view.x + view.width

    signal seekbarDropped()

    implicitWidth: view.count > 0 ? view.contentWidth : emptyWidth
    implicitHeight: VLCStyle.dp(30, VLCStyle.scale)

    function accepts(source) {
        return !!source && (source.controlId !== ControlListModel.SEEKBAR || acceptsSeekbar)
    }

    function dropEvent(drag, destIndex) {
        const source = drag.source
        if (source.controlId === ControlListModel.SEEKBAR) {
            root.seekbarDropped()
            drag.accept(Qt.MoveAction)
        } else if (source.dndView === root) {
            // moving from same section
            root.model.move(source.DelegateModel.itemsIndex, destIndex)
            source.visible = true
            drag.accept(Qt.MoveAction)
        } else if (!source.dndView) {
            // moving from the palette
            root.model.insert(destIndex, {"id" : source.controlId})
            drag.accept(Qt.CopyAction)
        } else {
            // moving between sections
            root.model.insert(destIndex, {"id" : source.controlId})
            source.dndView.model.remove(source.DelegateModel.itemsIndex)
            drag.accept(Qt.MoveAction)
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    DashedBox {
        x: root.alignment === Qt.AlignRight ? 0 : view.x + view.width
        y: 0
        width: root.width - view.width
        height: root.height

        visible: root.drawFreeSpace && width > 0 && (root.dashFreeSpace || PlayerControlbarControls.customizeDragging)
    }

    // the free space and the gaps; the delegates take the drops over themselves
    DropArea {
        id: zoneDrop

        anchors.fill: parent

        function overItem(x) {
            return view.indexAt(x - view.x + view.contentX, view.height / 2) >= 0
        }

        onEntered: (drag) => { drag.accepted = root.accepts(drag.source) }

        onDropped: (drop) => {
            // a delegate only refuses a drop over itself: no move
            if (overItem(drop.x))
                return

            const x = drop.x - view.x + view.contentX
            let destIndex = 0
            if (x >= 0) {
                destIndex = view.indexAt(x + view.spacing, view.height / 2)
                if (destIndex < 0)
                    destIndex = view.count
            }

            if ((drop.source.dndView === root) && (drop.source.DelegateModel.itemsIndex < destIndex))
                --destIndex

            root.dropEvent(drop, destIndex)
        }
    }

    Rectangle {
        x: view.count === 0 || root.alignment !== Qt.AlignRight ? view.x + view.width : view.x - width
        anchors.verticalCenter: parent.verticalCenter

        z: 2

        width: VLCStyle.dp(2, VLCStyle.scale)
        height: VLCStyle.icon_medium

        visible: zoneDrop.containsDrag && !zoneDrop.overItem(zoneDrop.drag.x)
        color: theme.accent
    }

    ListView {
        id: view

        readonly property Item zone: root

        x: {
            switch (root.alignment) {
            case Qt.AlignRight:
                return root.width - width
            case Qt.AlignHCenter:
                return (root.width - width) / 2
            default:
                return 0
            }
        }
        width: Math.min(contentWidth, root.width)
        height: root.height

        spacing: VLCStyle.margin_xsmall
        orientation: Qt.Horizontal
        clip: true
        // the delegates drag; a zone that overflows scrolls with the wheel
        interactive: false

        currentIndex: -1
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds

        VLCFlickableScrollHandler {
            fallbackScroll: true
            enabled: true
        }

        delegate: EditorDNDDelegate {
            height: Math.min((contentItem.implicitHeight > 0) ? contentItem.implicitHeight : Number.MAX_VALUE, root.height)

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            dndView: root
        }
    }
}
