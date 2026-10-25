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

    // tracks the end of the queue, it outlives the library view (see MainInterface)
    property QtObject playbackEnd: null

    // playback reached the end of the queue on its own
    readonly property bool ended: playbackEnd?.ended ?? false

    readonly property bool shown: Player.isStarted || ended

    // the video plus the seek bar, the queue stacks above it
    property Item mediaBlock: media

    // the card sits in the bottom-left corner instead of the bottom-right one
    property bool atLeft: false

    // the card is off its anchors, being dragged or settling into its corner
    property bool dragged: false

    // the room for the card, from the bottom of the top bar to its bottom edge, the queue list shrinks to fit
    property real maxHeight: Infinity

    // where the card may be dragged to, in the parent's coordinates
    property real dragXMin: 0
    property real dragXMax: 0
    property real dragYMin: 0
    property real dragYMax: 0

    // `hideControls` being `false` does not necessarily mean that the controls are shown
    property bool hideControls: MainCtx.usingTouch // by default controls are hidden with touch

    readonly property bool _mediaHovered: mediaHover.hovered || videoHover.hovered

    // the queue's list takes the focus of the card too, the video controls stay out of it
    readonly property bool _controlsShown: ended || root.activeFocus
                                           || (contentItem.activeFocus && !queueSection.activeFocus)
                                           || (!hideControls && _mediaHovered)

    // 12 spacing, 2 rows
    readonly property real _queueListMinimum: VLCStyle.dp(76, VLCStyle.scale)
    readonly property real _queueListHeight: Math.max(_queueListMinimum,
                                                      Math.min(VLCStyle.dp(215, VLCStyle.scale),
                                                               maxHeight - bottomPadding - queueHeader.height
                                                               - _queueCountHeight - 2 * column.spacing
                                                               - media.implicitHeight - infoBlock.implicitHeight
                                                               - infoBlock.Layout.topMargin - infoBlock.Layout.bottomMargin))
    readonly property real _queueCountHeight: VLCStyle.dp(64, VLCStyle.scale)

    visible: shown

    // the card moves by drag from anywhere but the queue's list, which flicks and reorders by drag
    Item {
        id: dragBody

        z: -1 // under the controls

        y: root.queueOpen ? root.contentItem.y + queueSection.y + queueSection.height : 0
        width: root.width
        height: root.height - y

        CardDragHandler {}
    }

    ParallelAnimation {
        id: settle

        NumberAnimation {
            target: root
            property: "x"
            to: root.atLeft ? root.dragXMin : root.dragXMax
            duration: VLCStyle.duration_long
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "y"
            to: root.dragYMax
            duration: VLCStyle.duration_long
            easing.type: Easing.OutCubic
        }

        onFinished: root.dragged = false // back on the anchors
    }

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

            // above the media block, the header strip reaches the card's edges
            FocusScope {
                id: queueSection

                Layout.fillWidth: true
                Layout.topMargin: -root.topPadding
                Layout.leftMargin: -root.leftPadding
                Layout.rightMargin: -root.rightPadding
                Layout.preferredHeight: queueHeader.height + root._queueCountHeight + root._queueListHeight

                visible: root.queueOpen

                Rectangle {
                    id: queueHeader

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    height: VLCStyle.dp(58, VLCStyle.scale)
                    color: "#151515"
                    radius: VLCStyle.dp(14, VLCStyle.scale)

                    Component.onCompleted: {
                        if (queueHeader.bottomLeftRadius !== undefined) { // TODO: Directly set when minimum Qt is 6.7
                            queueHeader.bottomLeftRadius = VLCStyle.dp(2, VLCStyle.scale)
                            queueHeader.bottomRightRadius = VLCStyle.dp(2, VLCStyle.scale)
                        }
                    }

                    CardDragHandler {}

                    CardLabel {
                        anchors.centerIn: parent

                        color: "#8F8F8F"
                        text: qsTr("Queue")
                    }
                }

                QueuePage {
                    anchors.top: queueHeader.bottom
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: VLCStyle.dp(375, VLCStyle.scale)
                    height: root._queueCountHeight + root._queueListHeight

                    compact: true

                    navigationParent: root
                    navigationUp: root.Navigation.upItem
                    navigationDown: root
                    onNavigationCancel: {
                        if (root.Navigation.cancelAction)
                            root.Navigation.cancelAction()
                    }
                }
            }

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

                            onClicked: {
                                root.playbackEnd?.dismiss()
                                MainPlaylistController.stop()
                            }

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

                            enabled: root.ended ? MainPlaylistController.currentIndex > 0
                                                : MainPlaylistController.hasPrev

                            onClicked: {
                                if (root.ended)
                                    MainPlaylistController.goTo(MainPlaylistController.currentIndex - 1, true)
                                else
                                    MainPlaylistController.prev()
                            }

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

                            onClicked: {
                                if (!root.ended)
                                    MainPlaylistController.togglePlayPause()
                                else if (MainPlaylistController.currentIndex < 0)
                                    MainPlaylistController.play()
                                else
                                    MainPlaylistController.goTo(MainPlaylistController.currentIndex, true)
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

                            enabled: root.ended ? MainPlaylistController.currentIndex + 1 < MainPlaylistController.count
                                                : MainPlaylistController.hasNext

                            onClicked: {
                                if (root.ended)
                                    MainPlaylistController.goTo(MainPlaylistController.currentIndex + 1, true)
                                else
                                    MainPlaylistController.next()
                            }

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
                id: infoBlock

                Layout.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                Layout.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                Layout.topMargin: VLCStyle.dp(4, VLCStyle.scale)
                Layout.bottomMargin: VLCStyle.dp(4, VLCStyle.scale)

                spacing: VLCStyle.dp(14, VLCStyle.scale)

                CardLabel {
                    Layout.fillWidth: true

                    text: root.playbackEnd?.title ?? ""
                }

                RowLayout {
                    spacing: VLCStyle.dp(20, VLCStyle.scale)

                    MetaGroup {
                        iconSource: "qrc:///redesign/mini/folder.svg"
                        text: Helpers.urlFolderName(Player.url.toString())
                    }

                    MetaGroup {
                        iconSource: "qrc:///redesign/mini/artist.svg"
                        text: root.playbackEnd?.artist ?? ""
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

    component CardDragHandler: DragHandler {
        target: root

        cursorShape: Qt.DragMoveCursor

        xAxis.minimum: root.dragXMin
        xAxis.maximum: root.dragXMax
        yAxis.minimum: root.dragYMin
        yAxis.maximum: root.dragYMax

        onActiveChanged: {
            if (active) {
                settle.stop()
                root.dragged = true // MainDisplay drops the anchors, the card keeps its place
            } else {
                root.atLeft = Helpers.snapToLeft(root.x, root.width, root.parent.width)
                settle.restart()
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
