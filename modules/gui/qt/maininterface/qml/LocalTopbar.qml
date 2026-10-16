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
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
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

    //whether the navigation pannel is actually visible or not
    property alias navigationVisible: navigationVisibilty.checked
    property alias playqueueVisible: playlistBtn.checked

    property alias navigationButton: navigationVisibilty

    // name of the folder holding the playing media, shown as a chip (player only)
    property string folderName: ""
    property bool showNavigationToggle: true
    property color tintColor: theme.bg.secondary

    signal toggleNavigationVisibility()
    signal togglePlayqueueVisibility()
    signal folderClicked()
    signal discoverRequested()
    // the player keeps its bars shown while the title bar is hovered or its menu is open
    signal requestLockUnlockAutoHide(bool lock)

    hoverEnabled: true
    onHoveredChanged: requestLockUnlockAutoHide(hovered)

    ///incomming signal to request all menu and popup to close
    function forceUnlock() {
        contextMenu.close()
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
        implicitWidth: navigationButtons.implicitWidth
                     + playqueueButtonsTop.implicitWidth
                     + VLCStyle.margin_xsmall * 2

        Item {
            id: navigationButtons

            implicitWidth: navigationButtonsRow.implicitWidth

            anchors {
                left: parent.left
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

                Widgets.BannerCone {
                    id: logo

                    anchors.verticalCenter: parent.verticalCenter

                    sourceSize.width: VLCStyle.icon_normal
                    sourceSize.height: VLCStyle.icon_normal
                    color: theme.accent
                }

                Widgets.IconToolButton {
                    id: menuBtn

                    // initial focus when the navigation toggle is hidden (player)
                    focus: !root.showNavigationToggle

                    visible: !MainCtx.hasToolbarMenu
                    font.pixelSize: VLCStyle.icon_banner
                    text: VLCIcons.ellipsis
                    description: qsTr("Menu")
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    checked: contextMenu.shown

                    Navigation.parentItem: navigationButtons
                    Navigation.rightItem: navigationVisibilty

                    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                    Menus.QmlGlobalMenu {
                        id: contextMenu
                        ctx: MainCtx
                        flat: true

                        onDiscoverRequested: root.discoverRequested()

                        onAboutToShow: root.requestLockUnlockAutoHide(true)
                        onAboutToHide: root.requestLockUnlockAutoHide(false)
                    }
                }

                Widgets.IconToolButton {
                    id: navigationVisibilty

                    visible: root.showNavigationToggle
                    focus: root.showNavigationToggle

                    text: VLCIcons.panel_left
                    description: qsTr("Show navigation menu")

                    AccessibleCompat.id: "sidebarToggleButton"

                    font.pixelSize: VLCStyle.icon_banner
                    height: VLCStyle.bannerButton_height
                    width: VLCStyle.bannerButton_width

                    onClicked: root.toggleNavigationVisibility()

                    Navigation.parentItem: navigationButtons
                    Navigation.leftItem: menuBtn
                    Navigation.rightItem: folderChip
                }

                // Figma player title bar: divider + folder of the playing media
                Rectangle {
                    visible: folderChip.visible
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(1, VLCStyle.scale)
                    height: VLCStyle.dp(20, VLCStyle.scale)
                    color: theme.separator
                }

                Widgets.ButtonExt {
                    id: folderChip

                    visible: root.folderName.length > 0
                    anchors.verticalCenter: parent.verticalCenter

                    iconTxt: VLCIcons.folder
                    text: root.folderName
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)

                    Accessible.description: qsTr("Back to the library")

                    Navigation.parentItem: navigationButtons
                    Navigation.leftItem: navigationVisibilty
                    Navigation.rightItem: playlistBtn

                    onClicked: root.folderClicked()
                }
            }
        }

        Item {
            id: playqueueButtonsTop

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
                    Navigation.leftItem: folderChip

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

        T.Label {
            id: windowTitle

            anchors.centerIn: parent
            width: Math.min(implicitWidth,
                            playqueueButtonsTop.x - (navigationButtons.x + navigationButtons.width) - VLCStyle.margin_large * 2)

            // the window title is empty until media plays
            text: MainCtx.intfMainWindow.title || qsTr("VLC media player")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideRight
            visible: width > VLCStyle.dp(40, VLCStyle.scale)

            Accessible.ignored: true
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
        active: root._showCSD
        source: VLCStyle.palette.hasCSDImage
                  ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                  : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
    }
}
