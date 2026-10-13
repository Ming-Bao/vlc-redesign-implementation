/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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
import QtQml.Models
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    readonly property int positionSliderY: controlBar.y + controlBar.sliderY

    readonly property string coverSource: {
        if (Player.artwork &&
            Player.artwork.toString())
            return Player.artwork
        else if (Player.hasVideoOutput)
            return VLCStyle.noArtVideoCover
        else
            return VLCStyle.noArtAlbumCover
    }

    // Only applicable in video mode:
    // Figma: solid bars, no gradient over the video
    property bool displayFadeRectangles: false
    property real implicitFadeRectangleHeight: VLCStyle.dp(206, VLCStyle.scale)

    // Private

    // Figma 247:445 / 3328:11554: in a window the video sits between the bars,
    // in fullscreen the bars overlay it and hide when idle
    property bool _controlsUnderVideo: (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
                                       || MainCtx.pinVideoControls // the user pins them in fullscreen too

    readonly property color _barColor: !windowTheme.palette.isDark ? windowTheme.bg.primary
                                     : _controlsUnderVideo ? "#1B1B1B"
                                                           : Qt.rgba(0x19 / 255, 0x19 / 255, 0x19 / 255, 0.95)

    property bool _keyPressed: false

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    Component.onCompleted: {
        MainCtx.preferHotkeys = true
    }
    Component.onDestruction: MainCtx.preferHotkeys = false

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBar.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        lockUnlockAutoHide(_controlsUnderVideo)
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // NOTE: We force the night theme when playing a video.
        palette: (MainCtx.hasEmbededVideo && MainCtx.pinVideoControls === false)
                 ? VLCStyle.darkPalette
                 : VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        // locks sent before the FSM starts are dropped, so apply the initial value here
        onStartedChanged: {
            if (started)
                rootPlayer.lockUnlockAutoHide(rootPlayer._controlsUnderVideo)
        }

        onForceUnlock:{
            controlBar.forceUnlock()

            topBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
    }


    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }


    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        anchors {
            left: parent.left
            right: parent.right
            top: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? topBar.bottom : parent.top
            bottom: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? controlBar.top : parent.bottom
        }

        sourceComponent: MainCtx.hasEmbededVideo ? videoComponent : audioComponent

        property int cursorShape

        // Have padding here, so that the content (unlike background) does not go behind the top bar or the control bar:
        property real topPadding: (anchors.top === parent.top) ? topBar.height : 0
        property real bottomPadding: (anchors.bottom === parent.bottom) ? controlBar.height : 0

        component TouchDragHandler : DragHandler {
            id: touchDragHandler

            acceptedDevices: PointerDevice.TouchScreen

            minimumPointCount: 1
            maximumPointCount: 1

            target: null

            dragThreshold: VLCStyle.margin_normal

            property vector2d lastActiveTranslation

            // TODO: Use `createComponent()` and load directly from module instead, since
            //       it is pointless to keep the `QQmlComponent` around for this object.
            readonly property Component wheelToVLCConverterComponent: Component { WheelToVLCConverter { } }

            property WheelToVLCConverter wheelToVLCConverter

            // We synthesize wheel event with pixel delta. It is a to-do to handle
            // touch properly with precision adjustment, like on Android:
            onActiveTranslationChanged: {
                if (active) {
                    console.assert(wheelToVLCConverter)

                    const delta = Qt.point(activeTranslation.x - lastActiveTranslation.x,
                                           activeTranslation.y - lastActiveTranslation.y)

                    // WheelToVLCConverter can not handle sole pixel delta now, so we also
                    // use angle delta. This is similar to wheel events on some platforms:
                    wheelToVLCConverter.customWheelEvent(delta,
                                                         delta,
                                                         Qt.NoButton,
                                                         Qt.NoModifier,
                                                         true)

                    lastActiveTranslation = activeTranslation
                }
            }

            onActiveChanged: {
                if (active) {
                    if (!wheelToVLCConverter) {
                        wheelToVLCConverter = wheelToVLCConverterComponent.createObject(touchDragHandler)
                        wheelToVLCConverter.vlcWheelKey.connect(MainCtx, MainCtx.sendVLCHotkey)
                    }
                } else {
                    lastActiveTranslation = Qt.vector2d(0, 0)
                }
            }
        }

        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseEvent)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !playerToolbarVisibilityFSM.isVisible
                            && !interactiveAutoHideTimer.running
                        value: Qt.BlankCursor
                    }

                    TouchDragHandler {

                    }
                }

                component FadeRectangle : Rectangle {
                    implicitHeight: rootPlayer.implicitFadeRectangleHeight

                    SGManipulator {
                        // The rectangle is the bottom-most item in the interface,
                        // it does not need blending even though it is not opaque.
                        // Since `Rectangle` does not provide explicit control over
                        // blending, we are using `SGManipulator`:
                        blending: false
                    }
                }

                FadeRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: topBar.opacity
                    visible: rootPlayer.displayFadeRectangles

                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                FadeRectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: controlBar.opacity

                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "black" }
                    }

                    visible: rootPlayer.displayFadeRectangles && !(controlBar.background && controlBar.background.visible)
                }
            }
        }

        Component {
            id: audioComponent

            FocusScope {
                id: audioFocusScope
                // Audio

                focus: true

                property real topPadding: playerSpecializationLoader.topPadding
                property real bottomPadding: playerSpecializationLoader.bottomPadding

                // Whether the full lyrics view is active
                readonly property bool lyricsMode: MainCtx.lyricsMode
                readonly property bool lyricsLayoutActive: lyricsMode
                                                        && Player.hasLyrics
                                                        && centerContent.width > VLCStyle.colWidth(6)

                // Reset sync when entering lyrics mode
                onLyricsModeChanged: {
                    if (lyricsMode && lyricsLoader.item)
                        lyricsLoader.item.lyricsSyncToPlayback = true
                }

                // background image
                Widgets.DualKawaseBlur {
                    id: blurredBackground

                    // Six pass is free here since we release the intermediate layers
                    // through unsetting `live` (see `liveTimer`):
                    mode: Widgets.DualKawaseBlur.Mode.SixPass
                    radius: 2

                    // We disable live when everything settles through `liveTimer`,
                    // which is important to release intermediate layers with static
                    // source:
                    live: true

                    //destination aspect ratio
                    readonly property real dar: parent.width / parent.height

                    anchors.centerIn: parent
                    width: (cover.sar < dar) ? parent.width :  parent.height * cover.sar
                    height: (cover.sar < dar) ? parent.width / cover.sar :  parent.height

                    source: textureProviderIndirection

                    postprocess: true
                    tint: bgtheme.palette.isDark ? "black" : "white"
                    tintStrength: 0.5
                    backgroundColor: bgtheme.bg.primary

                    readonly property ColorContext colorContext: ColorContext {
                        id: bgtheme
                        colorSet: ColorContext.View
                    }

                    // The window naturally clips the content, but having this saves some
                    // video memory, depending on the excess content in the last layer:
                    viewportRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2, parent.width, parent.height)

                    sourceTextureProviderObserver.onTextureChanged: {
                        liveTimer.transientTurnOnLive()
                    }

                    TextureProviderIndirection {
                        id: textureProviderIndirection

                        // This should not be necessary anymore since `DualKawaseBlur`
                        // does not create layer for the source implicitly as `MultiEffect`
                        // or `FastBlur` does as they deem necessary (in this case, it
                        // is not necessary). But due to a Qt bug when `mipmap: true` is
                        // used where texture sampling becomes broken, we need this as
                        // `QSGTextureView` has a workaround for that bug. This is totally
                        // acceptable as there is virtually no overhead.
                        source: cover
                    }

                    Component.onCompleted: {
                        // Blur layers are effect-size dependent, so once the user starts resizing the window (hence the effect),
                        // we should either momentarily turn on live, or repeatedly call `scheduleUpdate()`. Due to the optimization,
                        // calling `scheduleUpdate()` would continuously create and release intermediate layers, which would be a
                        // really bad idea. So instead, we turn on live and after some time passes turn it off again.
                        widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                        heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)

                        // In case texture provider observer never signals texture change:
                        liveTimer.transientTurnOnLive()
                    }

                    Timer {
                        id: liveTimer

                        repeat: false
                        interval: VLCStyle.duration_humanMoment

                        function transientTurnOnLive() {
                            if (!blurredBackground.sourceTextureIsValid)
                                return
                            blurredBackground.live = true
                            liveTimer.restart()
                        }

                        onTriggered: {
                            blurredBackground.live = false
                        }
                    }
                }

                MouseArea {
                    id: centerContent

                    readonly property ColorContext colorContext: ColorContext {
                        id: centerTheme
                        colorSet: ColorContext.View
                    }

                    anchors.fill: parent
                    anchors.topMargin: VLCStyle.margin_xsmall + audioFocusScope.topPadding
                    anchors.bottomMargin: VLCStyle.margin_xsmall + audioFocusScope.bottomPadding

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        wheelToVlc.qmlWheelEvent(wheel)
                    }

                    TouchDragHandler {
                        wheelToVLCConverter: wheelToVlc
                    }

                    WheelToVLCConverter {
                        id: wheelToVlc

                        onVlcWheelKey: (key) => MainCtx.sendVLCHotkey(key)
                    }

                    // ── Two-panel lyrics layout ────────────────────────
                    Item {
                        id: leftSideParent

                        visible: (opacity > 0.0) || (width > 0.0)

                        opacity: (lyricsLoader.item ? 1.0 : 0.0)

                        Behavior on opacity {
                            id: opacityBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { opacityBehavior.enabled = true })
                            }
                        }

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left

                        width: lyricsLoader.item ? (parent.width * 0.6) : 0.0

                        Behavior on width {
                            id: widthBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { widthBehavior.enabled = true })
                            }
                        }

                        Loader {
                            id: lyricsLoader

                            active: audioFocusScope.lyricsLayoutActive
                            sourceComponent: T.Pane {
                                // Swallow wheel events so scrolling the lyrics
                                // does not bubble up to the player and change
                                // the volume.
                                wheelEnabled: true

                                // Expose the inner Flickable's sync flag so the
                                // Loader's `item.lyricsSyncToPlayback` reaches
                                // through to LyricsFlickable in both directions.
                                property alias lyricsSyncToPlayback: lyricsFlickable.lyricsSyncToPlayback

                                implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                                        implicitContentWidth + leftPadding + rightPadding)
                                implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                         implicitContentHeight + topPadding + bottomPadding)

                                contentItem: LyricsFlickable {
                                    id: lyricsFlickable

                                    onPlayerPositionChangeRequested: (time) => {
                                        Player.setTime(time)
                                        lyricsFlickable.lyricsSyncToPlayback = true
                                    }
                                }
                            }
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            height: Math.min(implicitHeight, parent.height)
                        }
                    }

                    Item {
                        id: rightSideParent

                        visible: leftSideParent.visible

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.left: leftSideParent.right
                    }

                    ColumnLayout {
                        parent: leftSideParent.visible ? rightSideParent : centerContent

                        anchors.centerIn: parent
                        spacing: 0

                        Item {
                            id: coverItem
                            Layout.preferredHeight: rootPlayer.height / sizeConstant
                            Layout.preferredWidth: cover.paintedWidth
                            Layout.maximumHeight: centerContent.height
                            Layout.alignment: Qt.AlignHCenter

                            readonly property real sizeConstant: 2.7182

                            Image {
                                id: cover

                                //source aspect ratio
                                readonly property real sar: paintedWidth / paintedHeight
                                readonly property int maximumWidth: Helpers.alignUp((Screen.desktopAvailableWidth * eDPR / coverItem.sizeConstant), 32)
                                readonly property int maximumHeight: Helpers.alignUp((Screen.desktopAvailableHeight * eDPR / coverItem.sizeConstant), 32)

                                readonly property int maximumSize: Math.min(maximumWidth, maximumHeight)

                                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

                                readonly property url targetSource: VLCAccessImage.uri(rootPlayer.coverSource)

                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: targetSource
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                cache: false
                                asynchronous: true

                                onTargetSourceChanged: {
                                    cover.source = targetSource
                                }

                                onSourceChanged: {
                                    liveTimer.transientTurnOnLive()
                                }

                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        cover.source = VLCStyle.noArtAlbumCover
                                    }
                                }

                                sourceSize: Qt.size(maximumSize, maximumSize)

                                Accessible.role: Accessible.Graphic
                                Accessible.name: qsTr("Cover")

                                Component.onCompleted: {
                                    // After the update on source change, there can be another update when the mipmaps are generated.
                                    // We intentionally do not wait for this, initially using non-mipmapped source should be okay. As
                                    // the user should not be greeted with a black background until the mipmaps are ready, let alone
                                    // the possibility of knowing if the mipmaps are actually going to be ready as expected.
                                    // If the texture is not valid yet (which is signalled the latest), blur effect is going to queue
                                    // an update itself similar to the case when the source itself changes, so we do not check validity
                                    // of the texture here.
                                    blurredBackground.sourceTextureProviderObserver.hasMipmapsChanged.connect(blurredBackground,
                                                                                                              (hasMipmaps /*: bool */) => {
                                                                                                                  if (hasMipmaps) {
                                                                                                                      blurredBackground.scheduleUpdate()
                                                                                                                  }
                                                                                                              })
                                }

                                Widgets.RoundedRectangleShadow {
                                    color: Qt.rgba(0, 0, 0, .18)
                                    yOffset: VLCStyle.dp(24, VLCStyle.scale)
                                    blurRadius: VLCStyle.dp(54, VLCStyle.scale)
                                }

                                Widgets.RoundedRectangleShadow {
                                    color: Qt.rgba(0, 0, 0, .22)
                                    yOffset: VLCStyle.dp(5, VLCStyle.scale)
                                    blurRadius: VLCStyle.dp(14, VLCStyle.scale)
                                }
                            }
                        }

                        Widgets.SubtitleLabel {
                            id: albumLabel

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_xxlarge

                            Binding on visible {
                                delayed: true
                                when: albumLabel.componentCompleted
                                value: centerContent.height > (albumLabel.y + albumLabel.height)
                            }

                            text: Player.album
                            font.pixelSize: VLCStyle.fontSize_xxlarge
                            horizontalAlignment: Text.AlignHCenter
                            color: centerTheme.fg.primary
                            Accessible.description: qsTr("album")

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }
                        }

                        Widgets.MenuLabel {
                            id: artistLabel

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_small

                            Binding on visible {
                                delayed: true
                                when: artistLabel.componentCompleted
                                value: centerContent.height > (artistLabel.y + artistLabel.height)
                            }

                            text: Player.artist
                            font.weight: Font.Light
                            horizontalAlignment: Text.AlignHCenter
                            color: centerTheme.fg.primary
                            Accessible.description: qsTr("artist")

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }
                        }

                        Widgets.SubtitleLabel {
                            id: lyricsLabel

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large
                            // Pin width and height so the surrounding centered
                            // column does not shift when the current lyric
                            // changes between empty / 1 line / 2 lines. Text
                            // exceeding two lines wraps then elides on line 2.
                            Layout.preferredWidth: parent.parent.width - VLCStyle.margin_xlarge * 2
                            Layout.preferredHeight: (lyricsLabelTextMetrics.height * 2) + VLCStyle.margin_xxxsmall

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: lyricsLabel.componentCompleted

                                // Stay visible (reserving the 2-line slot) for the
                                // entire track when it has any lyrics, so the
                                // layout does not collapse between lyric lines.
                                value: Player.hasLyrics && !audioFocusScope.lyricsLayoutActive &&
                                       (centerContent.height > (lyricsLabel.y + lyricsLabel.height))
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            elide: Text.ElideRight

                            text: Player.currentLyric.text
                            font.pixelSize: VLCStyle.fontSize_xlarge
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            color: centerTheme.fg.primary

                            // TODO: Do not use `Binding` when minimum Qt is 6.12:
                            Binding {
                                target: lyricsLabel
                                property: "mutabilityGroup"
                                when: (lyricsLabel.mutabilityGroup !== undefined)
                                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                              : Item.StaticMutabilityGroup
                            }

                            TextMetrics {
                                id: lyricsLabelTextMetrics
                                font: lyricsLabel.font
                                text: "TEXT"
                            }

                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("Lyrics")
                            Accessible.description: text
                        }

                        Widgets.NavigableRow {
                            id: audioControls

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large

                            Binding on visible {
                                delayed: true
                                when: audioControls.componentCompleted
                                value: Player.videoTracks.count === 0 && centerContent.height > (audioControls.y + audioControls.height)
                            }

                            focus: true
                            spacing: VLCStyle.margin_xxsmall
                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: topBar
                            Navigation.downItem: syncToPlaybackCheckBox

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.skip_back
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.jumpBwd()
                                description: qsTr("Step back")

                                AccessibleCompat.id: "audioStepBackButton"
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.visualization
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.toggleVisualization()
                                description: qsTr("Visualization")

                                AccessibleCompat.id: "audioVisualizationButton"
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.topbar_music
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                checked: MainCtx.lyricsMode
                                onClicked: MainCtx.lyricsMode = !MainCtx.lyricsMode
                                description: qsTr("Lyrics")

                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Toggle lyrics view")
                                AccessibleCompat.id: "audioLyricsButton"
                            }

                            Widgets.IconToolButton{
                                text: VLCIcons.skip_for
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.jumpFwd()
                                description: qsTr("Step forward")

                                AccessibleCompat.id: "audioStepForwardButton"
                            }
                        }

                        // "Sync to Playback" checkbox pinned to bottom of right panel
                        Widgets.CheckBoxExt {
                            id: syncToPlaybackCheckBox

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_small

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: syncToPlaybackCheckBox.componentCompleted
                                value: audioFocusScope.lyricsLayoutActive &&
                                       centerContent.height > (syncToPlaybackCheckBox.y + syncToPlaybackCheckBox.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            text: qsTr("Sync lyrics to playback")
                            // Use a Binding element rather than an inline binding
                            // so manual clicks (which write `checked` directly)
                            // don't permanently break the source-of-truth link.
                            Binding on checked {
                                when: lyricsLoader.item
                                value: lyricsLoader.item ? lyricsLoader.item.lyricsSyncToPlayback : true
                                restoreMode: Binding.RestoreBindingOrValue
                            }
                            onClicked: {
                                if (lyricsLoader.item)
                                    lyricsLoader.item.lyricsSyncToPlayback = checked
                            }

                            Accessible.role: Accessible.CheckBox
                            Accessible.name: qsTr("Sync lyrics to playback position")
                            AccessibleCompat.id: "syncToPlaybackCheckBox"

                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: audioControls
                            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
                        }
                    }

                    Widgets.SubtitleLabel {
                        id: labelVolume

                        anchors.right: parent.right
                        anchors.top: parent.top

                        anchors.rightMargin: VLCStyle.margin_normal
                        anchors.topMargin: VLCStyle.margin_xxsmall

                        visible: false

                        text: qsTr("Volume %1%").arg(Math.round(Player.volume * 100))

                        color: centerTheme.fg.primary

                        font.weight: Font.Normal

                        Connections {
                            target: Player

                            function onVolumeChanged() {
                                animationVolume.restart()
                            }
                        }

                        SequentialAnimation {
                            id: animationVolume

                            PropertyAction { target: labelVolume; property: "visible"; value: true }

                            PauseAnimation { duration: VLCStyle.duration_humanMoment }

                            PropertyAction { target: labelVolume; property: "visible"; value: false }
                        }
                    }

                }
            }
        }
    }

    // menubar mode: the menu (and the window buttons with CSD) above the title bar, as in the library
    MenuTopbar {
        id: menuTopbar

        z: 2

        visible: MainCtx.hasToolbarMenu && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        enabled: visible

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        plListView: topBar.plListView
    }

    // Figma 247:445: the player keeps the window title bar, with the media folder as a chip
    LocalTopbar {
        id: topBar

        anchors.top: menuTopbar.visible ? menuTopbar.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1

        focus: true

        showNavigationToggle: false // the library side panel comes with the library redesign

        // the chip is also the way back to the library, so media without a folder
        // (streams, discs) get a generic label instead of no chip
        folderName: {
            const url = Player.url.toString()
            const parts = url.startsWith("file:") ? decodeURIComponent(url).split("/") : []
            const folder = (parts.length > 2) ? parts[parts.length - 2] : ""
            return folder.length > 0 ? folder : qsTr("Library")
        }

        tintColor: rootPlayer._barColor

        playqueueVisible: playlistVisibility.isPlaylistVisible

        plListView: (playlistWindowLoader?.status === Loader.Ready) ? playlistWindowLoader.item.playlistView : null

        Navigation.parentItem: rootPlayer
        Navigation.downItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup.contentItem
            if (MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            if (Player.isInteractive)
                return toggleControlBarButton
            return controlBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo) ? "visible" : "hidden"
        }

        onTogglePlayqueueVisibility: playlistVisibility.togglePlaylistVisibility()

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        // open the folder of the playing media in the browser, or the library for other media
        onFolderClicked: {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            MainCtx.playerView = false

            const folder = MainCtx.folderMRL(Player.url)
            const tree = MainCtx.folderTree(folder)
            if (tree)
                History.push(["network", "browse"], { tree: tree })
        }

        FadeControllerStateGroup {
            target: topBar
        }

        // like the previous player top bar, start with the focus here (not on a control
        // that may be rebuilt when the video output appears), without a keyboard reason
        Component.onCompleted: Qt.callLater(() => topBar.forceActiveFocus(Qt.OtherFocusReason))
    }

    // Figma "continue" toast: resume prompt above the control bar
    Rectangle {
        id: resumeToast

        // not bound to visible: a child reads invisible while its parent is hidden,
        // so the dialog could never show itself
        opacity: resumeDialog.visible ? 1 : 0
        z: 2

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(24, VLCStyle.scale)

        width: resumeDialog.implicitWidth + VLCStyle.dp(30, VLCStyle.scale)
        height: resumeDialog.implicitHeight + VLCStyle.dp(20, VLCStyle.scale)

        radius: VLCStyle.dp(8, VLCStyle.scale)
        color: windowTheme.palette.isDark ? Qt.rgba(0x19 / 255, 0x19 / 255, 0x19 / 255, 0.95)
                                          : windowTheme.bg.primary

        ResumeDialog {
            id: resumeDialog

            anchors.fill: parent
            anchors.topMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.bottomMargin: VLCStyle.dp(10, VLCStyle.scale)
            anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)

            maxWidth: Math.min(VLCStyle.dp(552, VLCStyle.scale), rootPlayer.width - VLCStyle.margin_large * 2)

            colorContext.palette: windowTheme.palette

            Navigation.parentItem: rootPlayer

            onHidden: {
                if (activeFocus)
                    controlBar.forceActiveFocus()
            }

            onVisibleChanged: rootPlayer.lockUnlockAutoHide(visible)
        }
    }

    QueuePanel {
        id: playlistpopup

        // the play queue state (button, hotkey, FSM) decides; the card follows it
        readonly property bool shown: playlistVisibility.isPlaylistVisible && MainCtx.playqueuePanel.docked

        parent: rootPlayer
        x: rootPlayer.width - width - VLCStyle.dp(20, VLCStyle.scale)
        y: rootPlayer.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
        maximumHeight: rootPlayer.positionSliderY - VLCStyle.dp(80, VLCStyle.scale)
        z: 1

        colorContext.palette: windowTheme.palette

        onShownChanged: shown ? open() : close()
        Component.onCompleted: if (shown) open()
        // Escape closes the card itself: keep the play queue state in step
        onClosed: if (playlistVisibility.isPlaylistVisible) playlistVisibility.togglePlaylistVisibility()
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBar.visible ? controlBar.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBar.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (interactiveAutoHideTimer.running === true
                     || controlBar.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBar.state === "hidden" ? parent.bottom : controlBar.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBar.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup.contentItem : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    ControlBar {
        id: controlBar

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        hoverEnabled: true

        focus: true

        rightPadding: VLCStyle.applicationHorizontalMargin
        leftPadding: VLCStyle.applicationHorizontalMargin
        bottomPadding: _compact ? VLCStyle.dp(11, VLCStyle.scale)
                                : VLCStyle.applicationVerticalMargin + VLCStyle.margin_xsmall

        // Figma Controls (default): ⏮ ▶ ⏭ · time · seek · duration · volume tracks settings queue
        compactStyle: true
        textPosition: ControlBar.TimeTextPosition.Inline
        // pre-redesign profiles fill the centre section and cannot host the inline seek bar
        inlineFallback: ControlBar.TimeTextPosition.LeftRightSlider
        sliderHeight: _compact ? VLCStyle.dp(28, VLCStyle.scale) : VLCStyle.heightBar_xxsmall
        topPadding: _compact ? VLCStyle.dp(11, VLCStyle.scale) : 0

        // hide right text so that it won't overlap with play queue
        showRemainingTime: (_textPosition !== ControlBar.TimeTextPosition.AboveSlider)
                           || !playlistVisibility.isPlaylistVisible

        onStateChanged: {
            if (state === "visible")
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup.contentItem
            if (Player.isInteractive)
                return toggleControlBarButton
            if (!MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            return topBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo) ? "visible" : "hidden"
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

        background: Rectangle {
            id: controlBarBackground

            color: rootPlayer._barColor
        }

        FadeControllerStateGroup {
            target: controlBar
        }
    }

    QmlAudioContextMenu {
        id: audioContextMenu

        ctx: MainCtx
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                audioContextMenu.popup(eventPoint.globalPosition)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        propagateComposedEvents: true
        cursorShape: undefined
        onClicked: {
            MainCtx.playerView = false
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
