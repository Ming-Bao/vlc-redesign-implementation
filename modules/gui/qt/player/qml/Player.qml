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

                Rectangle {
                    // Figma frame background, seen when there is no artwork to blur
                    anchors.fill: parent
                    color: bgtheme.palette.isDark ? "#1B1B1B" : bgtheme.bg.primary
                }

                // background image
                Widgets.DualKawaseBlur {
                    id: blurredBackground

                    visible: musicView.hasArt

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
                        source: cover.textureProviderItem
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

                    // Figma Player - Music 4767:23726: the cover, then "title - artist", spaced
                    // evenly between the title bar and the control bar (73 px gaps at 1080p)
                    Item {
                        id: musicView

                        // gaps are measured from the bars' edges, so undo centerContent's margin
                        anchors.fill: parent
                        anchors.topMargin: -VLCStyle.margin_xsmall
                        anchors.bottomMargin: -VLCStyle.margin_xsmall

                        readonly property real gap: Math.round(height * 0.074)
                        readonly property real coverSide: Math.max(0, Math.min(height - titleLabel.height - gap * 3,
                                                                                width - gap * 2))
                        readonly property real contentTop: (height - (coverSide + gap + titleLabel.height)) / 2
                        readonly property bool hasArt: Player.artwork.toString().length > 0
                                                       && cover.status !== Image.Error

                        Widgets.ImageExt {
                            id: cover

                            // source aspect ratio, for the blurred background
                            readonly property real sar: (implicitHeight > 0) ? implicitWidth / implicitHeight : 1
                            readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)
                            readonly property int maximumSize: Math.min(Helpers.alignUp(Screen.desktopAvailableWidth * eDPR / 2, 32),
                                                                        Helpers.alignUp(Screen.desktopAvailableHeight * eDPR / 2, 32))

                            x: (parent.width - width) / 2
                            y: musicView.contentTop
                            width: musicView.coverSide
                            height: musicView.coverSide

                            visible: musicView.hasArt
                            source: Player.artwork.toString().length > 0 ? VLCAccessImage.uri(Player.artwork) : ""
                            sourceSize: Qt.size(maximumSize, maximumSize)
                            fillMode: Image.PreserveAspectCrop
                            radius: VLCStyle.dp(20, VLCStyle.scale)
                            cache: false

                            onSourceChanged: liveTimer.transientTurnOnLive()

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

                            // Figma: 0 0 90.5px 64px rgba(255,255,255,0.03)
                            Widgets.RoundedRectangleShadow {
                                color: Qt.rgba(1, 1, 1, 0.03)
                                blurRadius: VLCStyle.dp(90, VLCStyle.scale)
                                implicitWidth: parent.width + VLCStyle.dp(128, VLCStyle.scale) + blurRadius * compensationFactor * 2
                                implicitHeight: parent.height + VLCStyle.dp(128, VLCStyle.scale) + blurRadius * compensationFactor * 2
                            }
                        }

                        Rectangle {
                            // no artwork: a dark tile instead of the light placeholder
                            x: cover.x
                            y: cover.y
                            width: cover.width
                            height: cover.height
                            visible: !musicView.hasArt
                            radius: cover.radius
                            color: centerTheme.palette.isDark ? "#191919" : centerTheme.bg.secondary

                            Widgets.IconLabel {
                                anchors.centerIn: parent
                                text: VLCIcons.topbar_music
                                font.pixelSize: VLCStyle.dp(96, VLCStyle.scale)
                                color: centerTheme.palette.isDark ? "#404040" : centerTheme.fg.secondary
                            }
                        }

                        T.Label {
                            id: titleLabel

                            x: (parent.width - width) / 2
                            y: cover.y + cover.height + musicView.gap
                            width: Math.min(implicitWidth, Math.max(musicView.coverSide, VLCStyle.dp(200, VLCStyle.scale)))

                            text: Player.artist ? qsTr("%1 - %2").arg(Player.title).arg(Player.artist) : Player.title
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                            font.weight: Font.Medium
                            color: centerTheme.palette.isDark ? "#969696" : centerTheme.fg.secondary

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
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
                return playlistpopup.currentList
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
        readonly property bool shown: playlistVisibility.isPlaylistVisible

        parent: rootPlayer
        x: rootPlayer.width - width - VLCStyle.dp(20, VLCStyle.scale)
        y: rootPlayer.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
        maximumHeight: rootPlayer.positionSliderY - VLCStyle.dp(80, VLCStyle.scale)
        z: 1

        colorContext.palette: windowTheme.palette

        onShownChanged: shown ? open() : close()
        Component.onCompleted: if (shown) open()
        // Escape closes the card itself: keep the play queue state in step
        // (only while the docked queue is still shown: undocking closes the card too)
        onClosed: if (playlistVisibility.isPlaylistVisible && MainCtx.playqueuePanel.docked)
                      playlistVisibility.togglePlaylistVisibility()

        navigationParent: rootPlayer
        navigationUp: topBar
        navigationDown: Player.isInteractive ? toggleControlBarButton : controlBar
        onNavigationCancel: {
            playlistVisibility.togglePlaylistVisibility()
            controlBar.forceActiveFocus()
        }
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
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup.currentList : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
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
                return playlistpopup.currentList
            if (Player.isInteractive)
                return toggleControlBarButton
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
        musicMode: !Player.hasVideoOutput

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
