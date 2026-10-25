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

import "SettingsData.js" as SettingsData

// The Figma settings window (frames "Settings - *", 1048 x 865): a frameless card with a top bar (search, page
// title, close), a sidebar of pages and the page content. Single instance, opened by Dialogs.qml.
Window {
    id: root

    // the selected page, an index into SettingsData.pages; kept for the session (the Loader in Dialogs.qml stays active)
    property int currentPage: 0
    property string searchText: ""
    // what the content area shows for the current page
    property Component pageComponent

    readonly property var pages: SettingsData.pages

    // transparent room around the card for its shadow
    readonly property real _shadowMargin: VLCStyle.dp(24, VLCStyle.scale)
    property bool _placed: false

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    transientParent: MainCtx.intfMainWindow
    title: qsTr("Settings")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette?.isDark ?? true
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
        const w = Math.min(VLCStyle.dp(1048, VLCStyle.scale) + m, Math.floor(scr.desktopAvailableWidth * 0.9))
        const h = Math.min(VLCStyle.dp(865, VLCStyle.scale) + m, Math.floor(scr.desktopAvailableHeight * 0.9))
        minimumWidth = Math.min(VLCStyle.dp(760, VLCStyle.scale) + m, w)
        minimumHeight = Math.min(VLCStyle.dp(480, VLCStyle.scale) + m, h)
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
        if (!activeFocusItem) {
            sidebar.quietFocus = true
            sidebar.forceActiveFocus()
        }
    }

    onClosing: SettingsBridge.save()

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

        // Escape closes, from whatever inside has focus (a popup or the search box handle theirs first)
        focus: true
        Keys.onEscapePressed: root.close()

        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root._dark ? Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.95) : theme.bg.primary

        // Figma: 0 8 15 #00000075
        Widgets.RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0x75 / 255)
            blurRadius: VLCStyle.dp(15, VLCStyle.scale)
            yOffset: VLCStyle.dp(8, VLCStyle.scale)
            implicitWidth: parent.width + blurRadius * compensationFactor * 2
            implicitHeight: parent.height + blurRadius * compensationFactor * 2
        }

        // first in the tree so that Tab goes sidebar, search, content
        SettingsSidebar {
            id: sidebar

            anchors.left: parent.left
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom

            pages: root.pages
            currentIndex: root.currentPage
            onPicked: (index) => root.currentPage = index
        }

        Rectangle {
            id: topBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: VLCStyle.dp(50, VLCStyle.scale)

            radius: card.radius
            color: root._dark ? "#090909" : theme.bg.secondary

            // square off the bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) root.startSystemMove()
            }

            Rectangle {
                id: searchBox

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(200, VLCStyle.scale)
                height: VLCStyle.dp(34, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._dark ? "#151515" : theme.bg.primary

                Image {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:///redesign/settings/search.svg"
                }

                TextInput {
                    id: searchField

                    anchors.left: searchIcon.right
                    anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter

                    activeFocusOnTab: true
                    clip: true
                    selectByMouse: true
                    text: root.searchText
                    onTextEdited: root.searchText = text

                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._dark ? "#EAEAEA" : theme.fg.primary
                    selectionColor: root._s.accentDim
                    selectedTextColor: "#EAEAEA"

                    Accessible.role: Accessible.EditableText
                    Accessible.name: qsTr("Search")

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !searchField.text && !searchField.preeditText
                        text: qsTr("Search")
                        font: searchField.font
                        color: root._dark ? "#404040" : theme.fg.secondary
                        Accessible.ignored: true
                    }
                }
            }

            Widgets.LabelExt {
                anchors.left: searchBox.right
                anchors.leftMargin: VLCStyle.dp(32, VLCStyle.scale)
                anchors.right: closeButton.left
                anchors.verticalCenter: parent.verticalCenter

                text: root.pages[root.currentPage].title
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._s.title
                Accessible.role: Accessible.Heading
            }

            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(14, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: width

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: closeHover.hovered || activeFocus ? (root._dark ? "#191919" : theme.bg.primary) : "transparent"
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Close")
                Accessible.onPressAction: root.close()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.close()
                        event.accepted = true
                    }
                }

                HoverHandler { id: closeHover }
                TapHandler { onTapped: root.close() }

                Image {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:///redesign/settings/close.svg"
                }
            }
        }

        // the page; Task 3's rows go in pageComponent
        FocusScope {
            id: content

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            activeFocusOnTab: true

            Loader {
                anchors.fill: parent
                focus: true
                sourceComponent: root.pageComponent
            }
        }

        // 6 px resize edges and corners
        component EdgeArea: MouseArea {
            required property int edges

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
