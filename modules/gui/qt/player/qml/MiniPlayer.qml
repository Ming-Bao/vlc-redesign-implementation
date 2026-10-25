/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Playlist
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// The floating mini player card of the library (Figma 970:3090 and variants)
T.Control {
    id: root

    property bool queueOpen: false

    // playback reached the end of the queue on its own; Task 3 drives it
    property bool ended: false

    readonly property bool shown: Player.isStarted || ended

    // the video plus the seek bar, the queue stacks above it
    property Item mediaBlock: media

    // the card sits in the bottom-left corner instead of the bottom-right one
    property bool atLeft: false

    // `hideControls` being `false` does not necessarily mean that the controls are shown
    property bool hideControls: MainCtx.usingTouch // by default controls are hidden with touch

    readonly property bool _mediaHovered: mediaHover.hovered || videoHover.hovered

    readonly property bool _controlsShown: ended || root.activeFocus || contentItem.activeFocus
                                           || (!hideControls && _mediaHovered)

    visible: shown

    // the hover controls only show once the card has the focus, so hand it to them then
    onActiveFocusChanged: {
        if (activeFocus)
            Qt.callLater(() => {
                if (Window.activeFocusItem === root)
                    playButton.forceActiveFocus(root.focusReason)
            })
    }

    width: VLCStyle.dp(391, VLCStyle.scale)
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    padding: VLCStyle.dp(8, VLCStyle.scale)

    Accessible.name: qsTr("Mini player")

    background: Rectangle {
        color: "#1B1B1B"
        radius: VLCStyle.dp(14, VLCStyle.scale)

        Widgets.RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0.38)
            blurRadius: VLCStyle.dp(5.9, VLCStyle.scale)
        }
    }

    // a focus scope, so that the controls know when one of them has the focus
    contentItem: FocusScope {
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column

            anchors.fill: parent

            spacing: VLCStyle.dp(20, VLCStyle.scale)

            ColumnLayout {
                id: media

                spacing: VLCStyle.dp(4, VLCStyle.scale)

                HoverHandler {
                    id: mediaHover
                }

                Rectangle {
                    id: videoArea

                    readonly property real borderWidth: VLCStyle.dp(2, VLCStyle.scale)

                    Layout.preferredWidth: VLCStyle.dp(375, VLCStyle.scale)
                    Layout.preferredHeight: VLCStyle.dp(211, VLCStyle.scale)

                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root.ended ? "#202020" : "#303030"

                    Image {
                        anchors.fill: parent
                        anchors.margins: videoArea.borderWidth

                        visible: !root.ended && !videoSurface.visible

                        source: Player.artwork.toString().length > 0 ? VLCAccessImage.uri(Player.artwork) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    VideoSurface {
                        id: videoSurface

                        anchors.fill: parent
                        anchors.margins: videoArea.borderWidth

                        visible: !root.ended && MainCtx.canShowVideoPIP && MainCtx.hasEmbededVideo
                                 && Player.hasVideoOutput

                        // no input to the video output: a double click there toggles fullscreen
                        enabled: false

                        videoSurfaceProvider: MainCtx.videoSurfaceProvider
                    }

                    // above the video surface, which hides the hover from the handlers below it
                    Item {
                        anchors.fill: parent

                        HoverHandler {
                            id: videoHover

                            Component.onCompleted: {
                                if (typeof blocking === 'boolean')
                                    blocking = true // Qt 6.3 feature
                            }
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.WithinBounds

                            onDoubleTapped: (eventPoint, button) => {
                                // Docs are lying, there is no `deviceType`: QTBUG-135104
                                if (eventPoint.device.type !== PointerDevice.TouchScreen)
                                    MainCtx.playerView = true
                            }

                            // a single click does nothing, the controls on hover do the work
                            onTapped: (eventPoint, button) => {
                                // Breaking the initial binding is intentional here:
                                if (eventPoint.device.type === PointerDevice.TouchScreen)
                                    root.hideControls = !root.hideControls
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        visible: root._controlsShown && !root.ended
                        color: Qt.rgba(0, 0, 0, 0.6)
                    }

                    Item {
                        anchors.fill: parent

                        visible: root._controlsShown

                        CardButton {
                            id: closeButton

                            Navigation.parentItem: root

                            x: VLCStyle.dp(14, VLCStyle.scale)
                            y: VLCStyle.dp(14, VLCStyle.scale)

                            imageSource: "qrc:///redesign/mini/close.svg"
                            description: qsTr("Stop")

                            onClicked: MainPlaylistController.stop()

                            Navigation.rightItem: popoutButton
                        }

                        CardButton {
                            id: popoutButton

                            Navigation.parentItem: root

                            x: parent.width - width - VLCStyle.dp(14, VLCStyle.scale)
                            y: VLCStyle.dp(14, VLCStyle.scale)

                            imageSource: "qrc:///redesign/mini/popout.svg"
                            description: qsTr("Open the player")

                            onClicked: MainCtx.playerView = true

                            Navigation.leftItem: closeButton
                            Navigation.rightItem: previousButton
                        }

                        CardButton {
                            id: previousButton

                            Navigation.parentItem: root

                            x: VLCStyle.dp(83, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter

                            glyph: true
                            imageSource: "qrc:///redesign/mini/previous.svg"
                            description: qsTr("Previous")

                            enabled: MainPlaylistController.hasPrev

                            onClicked: MainPlaylistController.prev()

                            Navigation.leftItem: popoutButton
                            Navigation.rightItem: playButton
                        }

                        CardButton {
                            id: playButton

                            Navigation.parentItem: root

                            x: VLCStyle.dp(165.6, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter

                            focus: true

                            readonly property bool playing: Player.playingState === Player.PLAYING_STATE_PLAYING

                            glyph: true
                            imageSource: root.ended ? "qrc:///redesign/mini/replay.svg"
                                       : playing ? "qrc:///redesign/mini/pause.svg"
                                                 : "qrc:///redesign/mini/play.svg"
                            description: root.ended ? qsTr("Replay")
                                       : playing ? qsTr("Pause")
                                                 : qsTr("Play")

                            // replay is wired by the ended state (Task 3)
                            onClicked: {
                                if (!root.ended)
                                    MainPlaylistController.togglePlayPause()
                            }

                            Navigation.leftItem: previousButton
                            Navigation.rightItem: nextButton
                        }

                        CardButton {
                            id: nextButton

                            Navigation.parentItem: root

                            x: VLCStyle.dp(233, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter

                            glyph: true
                            imageSource: "qrc:///redesign/mini/next.svg"
                            description: qsTr("Next")

                            enabled: MainPlaylistController.hasNext

                            onClicked: MainPlaylistController.next()

                            Navigation.leftItem: playButton
                            Navigation.rightItem: queueButton
                        }
                    }

                    // drawn over the picture so that the video corners stay inside it
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        color: "transparent"
                        border.width: videoArea.borderWidth
                        border.color: "#090909"
                    }
                }

                SliderBar {
                    Layout.fillWidth: true

                    blockStyle: true
                    barHeight: VLCStyle.dp(16, VLCStyle.scale)
                    handleShown: root._mediaHovered || root.ended

                    backgroundColor: "#090909"
                    progressColor: "#371F06"

                    enabled: Player.playingState === Player.PLAYING_STATE_PLAYING
                             || Player.playingState === Player.PLAYING_STATE_PAUSED

                    Accessible.role: Accessible.Slider
                    Accessible.name: qsTr("Progress")
                }
            }

            ColumnLayout {
                Layout.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                Layout.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                Layout.topMargin: VLCStyle.dp(4, VLCStyle.scale)
                Layout.bottomMargin: VLCStyle.dp(4, VLCStyle.scale)

                spacing: VLCStyle.dp(14, VLCStyle.scale)

                CardLabel {
                    Layout.fillWidth: true

                    // files without a title tag have only a name
                    text: Player.title || Player.name
                }

                RowLayout {
                    spacing: VLCStyle.dp(20, VLCStyle.scale)

                    MetaGroup {
                        iconSource: "qrc:///redesign/mini/folder.svg"
                        text: Helpers.urlFolderName(Player.url.toString())
                    }

                    MetaGroup {
                        iconSource: "qrc:///redesign/mini/artist.svg"
                        text: Player.artist
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    CardButton {
                        id: queueButton

                        Navigation.parentItem: root

                        implicitWidth: VLCStyle.dp(30, VLCStyle.scale)
                        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

                        imageSource: root.queueOpen ? "qrc:///redesign/mini/queue_active.svg"
                                                    : "qrc:///redesign/mini/queue.svg"
                        description: qsTr("Queue")

                        onClicked: root.queueOpen = !root.queueOpen

                        Navigation.leftItem: nextButton
                                    }
                }
            }
        }
    }

    component CardLabel: Text {
        color: "#969696"
        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
        elide: Text.ElideRight
    }

    // icon, 8 gap, text; hidden without text
    component MetaGroup: RowLayout {
        property alias iconSource: icon.source
        property alias text: label.text

        visible: label.text !== ""
        Layout.minimumWidth: 0
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth

        spacing: VLCStyle.dp(8, VLCStyle.scale)

        Image {
            id: icon

            sourceSize: Qt.size(VLCStyle.dp(24, VLCStyle.scale), VLCStyle.dp(24, VLCStyle.scale))
        }

        CardLabel {
            id: label

            Layout.fillWidth: true
        }
    }

    component CardButton: Widgets.ImageToolButton {
        // a 42.86 transport glyph rather than a 24 icon
        property bool glyph: false

        readonly property real _iconSize: VLCStyle.dp(glyph ? 42.857 : 24, VLCStyle.scale)

        sourceSize: Qt.size(_iconSize, _iconSize)

        focusPolicy: Qt.TabFocus
        opacity: enabled ? 1.0 : 0.4
    }
}
