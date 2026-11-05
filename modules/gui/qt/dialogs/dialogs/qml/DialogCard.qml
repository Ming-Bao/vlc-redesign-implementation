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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// The Figma dialog window (Settings, Open Network Stream, New Playlist, ...): a frameless card with a title bar, a
// body (the children) and a Cancel/Save footer, over a shadow. The owner closes the window on saved()/cancelled().
Window {
    id: root

    // the card's colour
    property color cardColor: _s.sidebarBg
    // the Figma frame size; the window is capped to 90 % of the screen
    property real figmaWidth: 1048
    property real figmaHeight: 800
    // the smallest size the user can resize to (default: fixed size); only a resizable window has resize edges
    property real minFigmaWidth: figmaWidth
    property real minFigmaHeight: figmaHeight
    property bool resizable: false
    property bool modal: false

    property bool showFooter: true
    property bool saveEnabled: false
    property string saveText: qsTr("Save")
    // shown in the footer between the buttons
    property string footerNote: ""

    // title bar: the title (the window title by default), and an item before it (the search box of Settings)
    property string headerTitle: title
    property real titleSize: VLCStyle.dp(14, VLCStyle.scale)
    property color titleColor: _s.value
    property real titleLeftMargin: VLCStyle.dp(10, VLCStyle.scale)
    property real barPadding: VLCStyle.dp(9, VLCStyle.scale)
    property Component headerExtra: null

    default property alias content: body.data

    signal saved()
    signal cancelled()

    // transparent room around the card for its shadow
    readonly property real _shadowMargin: VLCStyle.dp(24, VLCStyle.scale)
    property bool _placed: false

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    transientParent: MainCtx.intfMainWindow
    modality: modal ? Qt.ApplicationModal : Qt.NonModal

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    // Figma size, capped to 90 % of the screen and centred on the main window. Done once: later opens keep
    // the size and place the user gave the window.
    function _place() {
        // the screen under the centre of the main window, else the default one
        let scr = root.screen
        let cx = scr.virtualX + scr.width / 2
        let cy = scr.virtualY + scr.height / 2
        if (transientParent) {
            cx = transientParent.x + transientParent.width / 2
            cy = transientParent.y + transientParent.height / 2
            for (const sc of Qt.application.screens) {
                if (cx >= sc.virtualX && cx < sc.virtualX + sc.width && cy >= sc.virtualY && cy < sc.virtualY + sc.height) {
                    scr = sc
                    break
                }
            }
            root.screen = scr
        }
        // ponytail: the available area is taken to start at the screen's origin; a panel on the top or left edge
        // can push the window under it. Use QScreen.availableGeometry from C++ if that matters.
        const m = _shadowMargin * 2
        const w = Math.min(VLCStyle.dp(figmaWidth, VLCStyle.scale) + m, Math.floor(scr.desktopAvailableWidth * 0.9))
        const h = Math.min(VLCStyle.dp(figmaHeight, VLCStyle.scale) + m, Math.floor(scr.desktopAvailableHeight * 0.9))
        minimumWidth = Math.min(VLCStyle.dp(minFigmaWidth, VLCStyle.scale) + m, w)
        minimumHeight = Math.min(VLCStyle.dp(minFigmaHeight, VLCStyle.scale) + m, h)
        width = w
        height = h
        x = Math.max(scr.virtualX, Math.min(Math.round(cx - w / 2), scr.virtualX + scr.desktopAvailableWidth - w))
        y = Math.max(scr.virtualY, Math.min(Math.round(cy - h / 2), scr.virtualY + scr.desktopAvailableHeight - h))
    }

    function open() {
        if (!_placed) {
            _placed = true
            _place()
        }
        show()
        raise()
        requestActivate()
    }

    // takes the focus off the field being edited, so that it commits its value
    function takeFocus() {
        card.forceActiveFocus()
    }

    // asks before a destructive action; `yesCb` runs on OK, the button says okText
    function ask(text, yesCb, okText) {
        askDialog.ask(text, yesCb, null, { ok: okText ?? qsTr("OK"), cancel: qsTr("Cancel") })
    }

    Component.onCompleted: {
        if (MainCtx.createWindowWithoutRedirectionSurface) { // Win32
            const ret = MainCtx.createWindowWithoutRedirectionSurface(this)
            if (!ret)
                console.debug("MainCtx::createWindowWithoutRedirectionSurface(): returned false for window", this)
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: root._shadowMargin

        // Escape cancels, from whatever inside has focus (a popup or a field handle theirs first)
        focus: true
        Keys.onEscapePressed: root.cancelled()
        // Enter saves, except in a multi-line field (a TextEdit has lineCount)
        Keys.onReturnPressed: (event) => _enter(event)
        Keys.onEnterPressed: (event) => _enter(event)
        function _enter(event) {
            if (!root.showFooter || !root.saveEnabled || root.activeFocusItem?.lineCount !== undefined)
                return
            root.saved()
            event.accepted = true
        }

        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root.cardColor

        // Figma: 0 8 15 #00000075
        Widgets.RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0x75 / 255)
            blurRadius: VLCStyle.dp(15, VLCStyle.scale)
            yOffset: VLCStyle.dp(8, VLCStyle.scale)
            implicitWidth: parent.width + blurRadius * compensationFactor * 2
            implicitHeight: parent.height + blurRadius * compensationFactor * 2
        }

        // first in the tree so that Tab reaches the body before the title bar and the footer
        Item {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: footer.visible ? footer.top : parent.bottom
        }

        Rectangle {
            id: titleBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: VLCStyle.dp(50, VLCStyle.scale)

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

            // only the empty part of the bar (the title) moves the window, not the header item or the close button
            Item {
                anchors.left: extra.right
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                DragHandler {
                    target: null
                    onActiveChanged: if (active) root.startSystemMove()
                }
            }

            Loader {
                id: extra

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: root.headerExtra
            }

            Widgets.LabelExt {
                anchors.left: extra.right
                anchors.leftMargin: root.titleLeftMargin
                anchors.right: closeButton.left
                anchors.verticalCenter: parent.verticalCenter

                text: root.headerTitle
                elide: Text.ElideRight
                font.pixelSize: root.titleSize
                color: root.titleColor
                Accessible.role: Accessible.Heading
            }

            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: root.barPadding
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: width

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: closeHover.hovered || activeFocus ? root._s.face : "transparent"
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Close")
                Accessible.onPressAction: root.cancelled()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.cancelled()
                        event.accepted = true
                    }
                }

                HoverHandler { id: closeHover }
                TapHandler { onTapped: root.cancelled() }

                Image {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:///redesign/settings/close.svg"
                }
            }
        }

        Item {
            id: footer

            visible: root.showFooter
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
                    if (event.key === Qt.Key_Space) {
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
                onActivated: root.cancelled()
            }

            Widgets.LabelExt {
                anchors.centerIn: parent
                text: root.footerNote
                visible: text
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.label
            }

            FooterButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                enabled: root.saveEnabled
                opacity: enabled ? 1 : 0.5
                color: root._s.accentBg
                textColor: root._s.accent
                text: root.saveText
                onActivated: root.saved()
            }
        }

        CustomDialog {
            id: askDialog
            rootWindow: card
        }

        // 6 px resize edges and corners
        component EdgeArea: MouseArea {
            required property int edges

            enabled: root.resizable
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemResize(edges)
        }

        EdgeArea {
            edges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
            width: 6
        }
        EdgeArea {
            edges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
            width: 6
        }
        EdgeArea {
            edges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            height: 6
        }
        EdgeArea {
            edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            height: 6
        }
        EdgeArea {
            edges: Qt.LeftEdge | Qt.TopEdge; cursorShape: Qt.SizeFDiagCursor
            anchors { left: parent.left; top: parent.top }
            width: 12; height: 12
        }
        EdgeArea {
            edges: Qt.RightEdge | Qt.TopEdge; cursorShape: Qt.SizeBDiagCursor
            anchors { right: parent.right; top: parent.top }
            width: 12; height: 12
        }
        EdgeArea {
            edges: Qt.LeftEdge | Qt.BottomEdge; cursorShape: Qt.SizeBDiagCursor
            anchors { left: parent.left; bottom: parent.bottom }
            width: 12; height: 12
        }
        EdgeArea {
            edges: Qt.RightEdge | Qt.BottomEdge; cursorShape: Qt.SizeFDiagCursor
            anchors { right: parent.right; bottom: parent.bottom }
            width: 12; height: 12
        }
    }
}
