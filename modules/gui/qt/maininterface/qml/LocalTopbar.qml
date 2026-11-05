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
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.PlayerControls as Controls
import VLC.Dialogs
import VLC.Util

T.ToolBar {
    id: root

    Accessible.name: qsTr("Local top bar")
    AccessibleCompat.id: "localTopbar"

    property bool useAcrylic: true

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property bool _showCSD: MainCtx.clientSideDecoration
        && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)
        && !MainCtx.hasToolbarMenu

    // the player's title bar follows this profile model (PlayerControlbarModel::Topbar);
    // null keeps the library's fixed layout
    property Controls.PlayerControlbarModel controlModel: null
    readonly property bool _modelDriven: controlModel !== null

    // Customize Player: the zones are drawn in place of the rows
    property bool editing: false

    //whether the navigation pannel is actually visible or not (fixed layout)
    property alias navigationVisible: navigationVisibilty.checked
    property alias playqueueVisible: playlistBtn.checked

    // where the focus goes back to after the library panel: the sidebar button
    function focusNavigationButton(reason) {
        if (!_modelDriven) {
            navigationVisibilty.forceActiveFocus(reason)
            return
        }
        for (const row of _rows) {
            for (let i = 0; i < row.repeater.count; ++i) {
                const loader = row.repeater.itemAt(i)
                if (loader.controlId === Controls.ControlListModel.LIBRARY_PANEL && loader.item?.focus) {
                    loader.item.forceActiveFocus(reason)
                    return
                }
            }
        }
        _focusRow(-1, 1, reason)
    }

    property bool showNavigationToggle: true

    // initial focus: the first focusable control, whichever row it is in (every row's first
    // delegate claims focus, so the scope alone would pick one arbitrarily)
    function focusStart(reason) {
        if (!_modelDriven || !_focusRow(-1, 1, reason))
            forceActiveFocus(reason)
    }
    property color tintColor: theme.bg.secondary

    signal toggleNavigationVisibility()
    signal togglePlayqueueVisibility()
    signal discoverRequested()
    // the player keeps its bars shown while the title bar is hovered or its menu is open
    signal requestLockUnlockAutoHide(bool lock)
    // a control opened (or closed, null) a menu: the player keeps one open across both bars
    signal menuOpened(var menu)

    hoverEnabled: true
    onHoveredChanged: requestLockUnlockAutoHide(hovered)

    ///incomming signal to request all menu and popup to close
    function forceUnlock() {
        menuBtn.forceUnlock()
        for (const row of _rows)
            row.forceUnlock()
    }

    readonly property var _rows: [leftRow, centerRow, rightRow]

    // focuses the first (step 1) or last (step -1) focusable control of the rows after (before) `from`
    function _focusRow(from, step, reason) {
        for (let r = from + step; r >= 0 && r < _rows.length; r += step) {
            const repeater = _rows[r].repeater
            for (let i = (step > 0 ? 0 : repeater.count - 1); i >= 0 && i < repeater.count; i += step) {
                const item = repeater.itemAt(i)?.item
                if (item?.focus) {
                    item.forceActiveFocus(reason)
                    return true
                }
            }
        }
        return false
    }

    // one of the three rows of the model-driven bar
    component BarRow: RowLayout {
        id: row

        required property Item bar
        property Controls.ControlListModel source: null
        property alias repeater: repeater
        property int index: 0

        signal requestLockUnlockAutoHide(bool lock)
        signal menuOpened(var menu)
        signal forceUnlock()

        visible: false

        ControlRepeater {
            id: repeater

            model: Controls.ControlListFilter {
                sourceModel: row.source

                player: Player
                ctx: MainCtx
            }

            availableWidth: row.width
            availableHeight: row.height

            Navigation.parentItem: row.bar
            Navigation.leftAction: function() { return row.bar._focusRow(row.index, -1, Qt.BacktabFocusReason) }
            Navigation.rightAction: function() { return row.bar._focusRow(row.index, 1, Qt.TabFocusReason) }

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(row.requestLockUnlockAutoHide)
                menuOpened.connect(row.menuOpened)
                row.forceUnlock.connect(repeater.forceUnlock)
            }
        }
    }

    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                             implicitContentWidth + leftPadding + rightPadding + (_showCSD ? csdButtons.implicitWidth : 0))

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    background:  Widgets.AcrylicBackground {
        enabled: root.useAcrylic
        tintColor: root.tintColor
    }

    contentItem: Item {

        implicitHeight: VLCStyle.globalToolbar_height
        implicitWidth: logo.width
                     + (root._modelDriven ? leftRow.implicitWidth + centerRow.implicitWidth + rightRow.implicitWidth
                                          : navigationButtons.implicitWidth + playqueueButtonsTop.implicitWidth)
                     + VLCStyle.margin_xsmall * 2

        Widgets.BannerCone {
            id: logo

            anchors {
                left: parent.left
                leftMargin: VLCStyle.margin_xsmall
                verticalCenter: parent.verticalCenter
            }

            sourceSize.width: VLCStyle.icon_normal
            sourceSize.height: VLCStyle.icon_normal
            color: theme.accent
        }

        // the model-driven bar: left beside the cone, centre on the window's centre
        // (as the fixed title is), right at the edge
        BarRow {
            id: leftRow

            bar: root
            index: 0
            source: root.controlModel?.left ?? null
            visible: root._modelDriven && !root.editing
            spacing: VLCStyle.margin_xsmall

            anchors {
                left: logo.right
                leftMargin: VLCStyle.margin_xsmall
                top: parent.top
                bottom: parent.bottom
            }

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.menuOpened(menu)
        }

        BarRow {
            id: centerRow

            bar: root
            index: 1
            source: root.controlModel?.center ?? null
            visible: root._modelDriven && !root.editing
            spacing: VLCStyle.margin_xsmall

            // keeps the centre of the window while there is room on both sides
            readonly property real room: 2 * Math.min(parent.width / 2 - (leftRow.x + leftRow.width),
                                                      rightRow.x - parent.width / 2)
                                         - VLCStyle.margin_large * 2

            // whole pixels: a layout rounds down, which would elide text that fits
            width: Math.max(0, Math.min(Math.ceil(implicitWidth), room))

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.menuOpened(menu)
        }

        BarRow {
            id: rightRow

            bar: root
            index: 2
            source: root.controlModel?.right ?? null
            visible: root._modelDriven && !root.editing

            anchors {
                right: parent.right
                // the window buttons are flush with the edge
                rightMargin: root._showCSD ? 0 : VLCStyle.margin_xsmall
                top: parent.top
                bottom: parent.bottom
            }

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.menuOpened(menu)
        }

        // Customize Player's zones; an empty one shows while something is dragged (Figma 2160:7437)
        Loader {
            anchors.fill: parent
            active: root.editing

            sourceComponent: Item {
                EditorDNDView {
                    id: editLeft

                    x: logo.x + logo.width + VLCStyle.margin_xsmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, editCenter.x - x)

                    model: root.controlModel?.left ?? null
                    dashFreeSpace: false
                    emptyWidth: VLCStyle.dp(120, VLCStyle.scale)
                }

                EditorDNDView {
                    id: editCenter

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - 2 * editRight.width - VLCStyle.margin_large * 2)

                    model: root.controlModel?.center ?? null
                    alignment: Qt.AlignHCenter
                    dashFreeSpace: false
                    emptyWidth: VLCStyle.dp(120, VLCStyle.scale)
                }

                EditorDNDView {
                    id: editRight

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.margin_xsmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth

                    model: root.controlModel?.right ?? null
                    alignment: Qt.AlignRight
                    spacing: 0
                    dashFreeSpace: false
                    emptyWidth: VLCStyle.dp(120, VLCStyle.scale)
                }
            }
        }

        // the library's fixed layout
        Item {
            id: navigationButtons

            visible: !root._modelDriven
            implicitWidth: navigationButtonsRow.implicitWidth

            anchors {
                left: logo.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: VLCStyle.margin_xsmall
            }

            Navigation.parentItem: root

            Row {
                id: navigationButtonsRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_xsmall

                Navigation.parentItem: root
                Navigation.rightItem: playqueueButtonsTop

                Controls.MoreMenuButton {
                    id: menuBtn

                    anchors.verticalCenter: parent.verticalCenter

                    // initial focus when the navigation toggle is hidden
                    focus: !root.showNavigationToggle

                    Navigation.parentItem: navigationButtons
                    Navigation.rightItem: navigationVisibilty

                    hostHandles: true
                    onDiscoverRequested: root.discoverRequested()
                    onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.menuOpened(menu)
                }

                Controls.LibraryPanelButton {
                    id: navigationVisibilty

                    anchors.verticalCenter: parent.verticalCenter

                    visible: root.showNavigationToggle
                    focus: root.showNavigationToggle

                    Navigation.parentItem: navigationButtons
                    Navigation.leftItem: menuBtn

                    hostHandles: true
                    onClicked: root.toggleNavigationVisibility()
                }
            }
        }

        Item {
            id: playqueueButtonsTop

            visible: !root._modelDriven
            implicitWidth: playqueueButtonsTopRow.implicitWidth

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                //put the buttons below the CSD if we have enough space
                rightMargin: VLCStyle.margin_xsmall
                    + ((root._showCSD && root.topPadding < csdButtons.height)
                        ? Math.max(csdButtons.width - root.rightPadding, 0)
                        : 0)
            }

            Navigation.parentItem: root

            Row {
                id: playqueueButtonsTopRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_normal

                Navigation.parentItem: root
                Navigation.leftItem: navigationButtons

                PlaylistPane.PlaylistToggleButton {
                    id: playlistBtn

                    plListView: root.plListView

                    Navigation.parentItem: playqueueButtonsTop
                    Navigation.rightItem: fullscreenBtn
                    Navigation.leftItem: navigationVisibilty

                    onClicked:  root.togglePlayqueueVisibility()
                }

                Widgets.IconToolButton {
                    id: fullscreenBtn

                    font.pixelSize: VLCStyle.icon_banner
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen
                                                                                     : VLCIcons.fullscreen
                    description: qsTr("Fullscreen")

                    Navigation.parentItem: playqueueButtonsTop
                    Navigation.leftItem: playlistBtn

                    onClicked: MainCtx.toggleInterfaceFullScreen()
                }
            }
        }

        Controls.MediaTitleWidget {
            id: windowTitle

            anchors.centerIn: parent
            width: Math.min(implicitWidth,
                            playqueueButtonsTop.x - (navigationButtons.x + navigationButtons.width) - VLCStyle.margin_large * 2)

            visible: !root._modelDriven && width > VLCStyle.dp(40, VLCStyle.scale)
        }

        Loader {
            z: -1

            anchors.fill: parent
            active: root._showCSD
            sourceComponent: Widgets.CSDTitlebarTapNDrapHandler {
            }
        }
    }

    Loader {
        id: csdButtons

        //csd button are
        parent:  root
        anchors {
            right: parent.right
            top: parent.top
        }

        height: VLCStyle.globalToolbar_height
        active: root._showCSD && !root._modelDriven
        source: VLCStyle.palette.hasCSDImage
                  ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                  : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
    }
}
