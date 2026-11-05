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
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Util

import "qrc:/qt/qml/VLC/Dialogs/CustomizePalette.js" as Palette

// Customize Player's card (Figma 2107:5604): over the player, sharing the window's drag surface with its bars. The
// bars themselves are the live preview; the player keeps the other input off them while MainCtx.customizingPlayer.
FocusScope {
    id: root

    // the room between the player's bars
    property real barsTop: 0
    property real barsBottom: height
    // the bottom row's model, the one the player shows
    property PlayerControlbarModel bottomModel: null

    focus: true

    readonly property ControlbarProfileModel _profiles: MainCtx.controlbarProfileModel
    readonly property ControlbarProfile _profile: _profiles.currentModel
    readonly property PlayerControlbarModel _topbar: _profile?.getModel(PlayerControlbarModel.Topbar) ?? null

    // the palette's entries; a control only an older profile holds (Slower, Open...) joins them for the session, so
    // dragging it off doesn't lose it
    property var _items: Palette.items
    property var _available: []

    // where to go back on close
    property bool _wasPlayerView: false
    property bool _wasMinimalView: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    function _refresh() {
        const placed = []
        for (const model of [_topbar, bottomModel]) {
            if (model)
                placed.push(...model.left.getControls(), ...model.center.getControls(), ...model.right.getControls())
        }

        for (const id of placed) {
            if (!_items.some(i => i.id === id))
                _items = _items.concat({ id: id, label: PlayerControlbarControls.control(id).text ?? "" })
        }

        _available = Palette.available(_items, placed)
    }

    function _close(save) {
        // an Escape or Enter during a drag: the MouseArea that would end it goes away with this
        PlayerControlbarControls.customizeDragging = false

        if (save)
            _profiles.save()
        else
            _profiles.reload()

        MainCtx.customizingPlayer = false

        MainCtx.minimalView = _wasMinimalView
        // the player has nothing to show if the media ended meanwhile (MainInterface doesn't leave it during the edit)
        MainCtx.playerView = _wasPlayerView && Player.playingState !== Player.PLAYING_STATE_STOPPED
    }

    Component.onCompleted: {
        // reload() brings back what is saved now, should this session be cancelled
        _profiles.save(false)

        _wasPlayerView = MainCtx.playerView
        _wasMinimalView = MainCtx.minimalView
        MainCtx.minimalView = false
        MainCtx.playerView = true

        _refresh()
        forceActiveFocus()
    }

    // later: a drop is still running in the delegate this rebuilds
    Connections {
        target: root._profile
        function onControlListChanged() { Qt.callLater(root._refresh) }
    }
    onBottomModelChanged: Qt.callLater(root._refresh)

    Keys.onEscapePressed: _close(false)
    Keys.onReturnPressed: if (_profile?.dirty) _close(true)
    Keys.onEnterPressed: if (_profile?.dirty) _close(true)

    Rectangle {
        id: card

        readonly property real _margin: VLCStyle.dp(20, VLCStyle.scale)

        width: Math.min(VLCStyle.dp(1048, VLCStyle.scale), root.width - _margin * 2)
        height: Math.min(VLCStyle.dp(655, VLCStyle.scale), root.barsBottom - root.barsTop - _margin * 2)
        x: (root.width - width) / 2
        y: root.barsTop + (root.barsBottom - root.barsTop - height) / 2

        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.windowBg

        // Figma: 0 8 15 #00000075
        Widgets.RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0x75 / 255)
            blurRadius: VLCStyle.dp(15, VLCStyle.scale)
            yOffset: VLCStyle.dp(8, VLCStyle.scale)
            implicitWidth: parent.width + blurRadius * compensationFactor * 2
            implicitHeight: parent.height + blurRadius * compensationFactor * 2
        }

        // the card keeps the pointer from the player below
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        // the box: a control dropped on the card leaves the bar; the seekbar stays (it bounces back)
        DropArea {
            anchors.fill: parent

            onEntered: (drag) => {
                drag.accepted = !!drag.source?.dndView
            }
            onDropped: (drop) => {
                drop.source.dndView.model.remove(drop.source.DelegateModel.itemsIndex)
                drop.accept(Qt.MoveAction)
            }
        }

        Rectangle {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: VLCStyle.dp(94, VLCStyle.scale)

            radius: card.radius
            color: root._s.topBar

            // square off the bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Widgets.LabelExt {
                x: VLCStyle.dp(19, VLCStyle.scale) // bar padding 9, title padding 10
                y: (VLCStyle.dp(50, VLCStyle.scale) - height) / 2

                text: qsTr("Customize Player")
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.value
                Accessible.role: Accessible.Heading
            }

            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
                y: VLCStyle.dp(9, VLCStyle.scale)
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: width

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: closeHover.hovered || activeFocus ? root._s.face : "transparent"
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Close")
                Accessible.onPressAction: root._close(false)

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root._close(false)
                        event.accepted = true
                    }
                }

                HoverHandler { id: closeHover }
                TapHandler { onTapped: root._close(false) }

                Image {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:///redesign/settings/close.svg"
                }
            }

            Widgets.LabelExt {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: VLCStyle.dp(19, VLCStyle.scale)
                anchors.rightMargin: VLCStyle.dp(19, VLCStyle.scale)
                y: VLCStyle.dp(50, VLCStyle.scale) + (VLCStyle.dp(44, VLCStyle.scale) - height) / 2

                text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.label
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Flickable {
            id: paletteView

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // only the palette's rows scroll: dragging a cell moves that cell
            interactive: false

            contentHeight: grid.y + grid.height - _rowGap

            readonly property real _columnWidth: VLCStyle.dp(110, VLCStyle.scale) // 86 + the column gap
            readonly property real _rowGap: VLCStyle.dp(20, VLCStyle.scale)

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            VLCFlickableScrollHandler {
                fallbackScroll: true
                enabled: true
            }

            Flow {
                id: grid

                x: VLCStyle.dp(34, VLCStyle.scale)
                y: VLCStyle.dp(34, VLCStyle.scale)
                width: Math.max(paletteView._columnWidth, paletteView.width - x * 2 + VLCStyle.dp(24, VLCStyle.scale))

                Repeater {
                    model: root._available

                    delegate: Item {
                        id: cell

                        required property var modelData

                        width: paletteView._columnWidth
                        height: VLCStyle.dp(98, VLCStyle.scale) + paletteView._rowGap

                        MouseArea {
                            id: cellMouse

                            width: VLCStyle.dp(86, VLCStyle.scale)
                            height: VLCStyle.dp(98, VLCStyle.scale)

                            cursorShape: pressed ? Qt.DragMoveCursor : Qt.OpenHandCursor

                            drag.target: paletteDrag
                            drag.smoothed: false

                            drag.onActiveChanged: {
                                if (drag.active) {
                                    PlayerControlbarControls.customizeDragging = true
                                    paletteDrag.controlId = cell.modelData.id
                                    paletteDrag.glyph = glyph.text
                                    paletteDrag.Drag.start()
                                } else {
                                    paletteDrag.Drag.drop()
                                    PlayerControlbarControls.customizeDragging = false
                                }
                            }

                            onPressed: {
                                const pos = mapToItem(paletteDrag.parent, mouseX, mouseY)
                                paletteDrag.x = pos.x + VLCStyle.dragDelta
                                paletteDrag.y = pos.y + VLCStyle.dragDelta
                            }

                            DashedBox {
                                id: glyphBox

                                anchors.horizontalCenter: parent.horizontalCenter
                                width: VLCStyle.dp(30, VLCStyle.scale)
                                height: VLCStyle.dp(32, VLCStyle.scale)

                                Widgets.IconLabel {
                                    id: glyph

                                    anchors.centerIn: parent
                                    text: PlayerControlbarControls.control(cell.modelData.id).label ?? ""
                                    font.pixelSize: VLCStyle.icon_toolbar
                                    // Figma: a dim square
                                    color: cell.modelData.id === ControlListModel.THUMBNAIL_WIDGET ? root._s.placeholder
                                                                                                    : root._s.value
                                }

                                // the Divider cell shows the line itself
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: cell.modelData.id === ControlListModel.DIVIDER
                                    // Figma's cell: an 18 px line, 1.5 wide, round caps, #373737
                                    width: VLCStyle.dp(1.5, VLCStyle.scale)
                                    height: VLCStyle.dp(19.5, VLCStyle.scale)
                                    radius: width / 2
                                    color: "#373737"
                                }
                            }

                            Widgets.LabelExt {
                                anchors.top: glyphBox.bottom
                                anchors.topMargin: VLCStyle.dp(8, VLCStyle.scale)
                                width: parent.width

                                text: cell.modelData.label
                                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                                color: root._s.value
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.dp(72, VLCStyle.scale)

            component FooterButton: Rectangle {
                id: button

                property string text
                property color textColor
                signal activated()

                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(100, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)
                radius: VLCStyle.dp(6, VLCStyle.scale)
                activeFocusOnTab: true
                border.width: activeFocus ? 1 : 0
                border.color: textColor

                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.onPressAction: activated()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        activated()
                        event.accepted = true
                    }
                }
                TapHandler { enabled: button.enabled; onTapped: button.activated() }

                Widgets.LabelExt {
                    anchors.centerIn: parent
                    text: button.text
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    font.weight: Font.DemiBold
                    color: button.textColor
                }
            }

            FooterButton {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                color: root._s.box
                textColor: root._s.value
                text: qsTr("Cancel")
                onActivated: root._close(false)
            }

            FooterButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                enabled: root._profile?.dirty ?? false
                opacity: enabled ? 1 : 0.5
                color: root._s.accentBg
                textColor: root._s.accent
                text: qsTr("Save")
                onActivated: root._close(true)
            }
        }
    }

    // what follows the pointer out of the palette; the drag's source, so it outlives the cell a drop removes
    Item {
        id: paletteDrag

        property int controlId: -1
        property alias glyph: dragGlyph.text

        width: VLCStyle.dp(30, VLCStyle.scale)
        height: VLCStyle.dp(32, VLCStyle.scale)
        z: 1000

        visible: Drag.active
        Drag.source: paletteDrag
        Drag.hotSpot: Qt.point(-VLCStyle.dragDelta, -VLCStyle.dragDelta)

        DashedBox {
            anchors.fill: parent
        }

        Widgets.IconLabel {
            id: dragGlyph

            anchors.centerIn: parent
            font.pixelSize: VLCStyle.icon_toolbar
            color: root._s.value
        }
    }
}
