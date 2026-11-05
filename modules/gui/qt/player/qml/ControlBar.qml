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


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

T.Pane {
    id: root

    enum TimeTextPosition {
        Hide,
        AboveSlider,
        LeftRightSlider,
        Inline // time + slider inside the controls row, between left and right sections
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    topInset: (_textPosition === ControlBar.TimeTextPosition.Inline || _twoRows) ? 0 : sliderY

    bottomPadding: VLCStyle.margin_xsmall

    readonly property real sliderY: mapFromItem(contentItem, 0, contentItem.sliderY).y
    property int textPosition: ControlBar.TimeTextPosition.AboveSlider
    property int identifier: -1
    property real sliderHeight: VLCStyle.heightBar_xxsmall
    property real bookmarksHeight: VLCStyle.controlBarBookmarksHeight
    property bool showRemainingTime: true

    // compact (mini player) look: block seek bar, pill play button, muted time labels
    property bool compactStyle: false
    // music player: the seek bar is drawn as the track's waveform (needs the compact look)
    property bool musicMode: false
    property color backgroundColor: theme.bg.primary

    // Inline needs the spacer slot of the controls row; a profile that fills the
    // centre section (e.g. saved before the redesign) falls back to this position
    property int inlineFallback: ControlBar.TimeTextPosition.LeftRightSlider

    // the profile's seek row (PlayerControlbarModel::SeekRow): when it holds anything the
    // seek bar goes to its own row with the times beside it (Figma 2160:6137)
    property PlayerControlbarModel seekRowModel: null

    readonly property bool _seekRowUsed: !!seekRowModel && !seekRowModel.empty

    // Customize Player: the controls row is drawn as dashed zones, with the seekbar one more item
    property bool editing: false

    readonly property PlayerControlbarModel _bottomModel: contentItem.playerControlLayout.model

    readonly property int _textPosition: {
        if (_seekRowUsed)
            return ControlBar.TimeTextPosition.LeftRightSlider
        // a filled centre section leaves no spacer to hold it inline
        if (textPosition === ControlBar.TimeTextPosition.Inline
                && (editing ? (_bottomModel?.center.count ?? 0) > 0 : !contentItem.playerControlLayout.fillerItem))
            return inlineFallback
        return textPosition
    }

    // the compact look applies to the inline layout and to the seek row (Figma 2160:6137)
    readonly property bool _compact: compactStyle && (_textPosition === ControlBar.TimeTextPosition.Inline || _seekRowUsed)
    // the compact bar's two rows: the seek row and the controls (Figma 2160:6137), which Customize Player keeps while
    // the seekbar is inline, the seek row being a place to drop it
    readonly property bool _twoRows: compactStyle && (_seekRowUsed || editing)
    readonly property bool _dark: theme.palette.isDark
    readonly property bool _sideTimes: (_textPosition === ControlBar.TimeTextPosition.LeftRightSlider
                                        || _textPosition === ControlBar.TimeTextPosition.Inline)

    property var menu: undefined

    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        if (contentItem.trackPositionSlider)
            contentItem.trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // the seekbar dropped into the bottom centre: the zone's items make room, to the end of the left zone
    function _moveSeekbarInline() {
        for (const id of _bottomModel.center.getControls())
            _bottomModel.left.insert(_bottomModel.left.count, {"id": id})
        _bottomModel.center.clear()
        seekRowModel.left.clear()
    }

    TextMetrics {
        id: timeTextMetrics
        font.pixelSize: (root._textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.dp(15, VLCStyle.scale)
                      : root._sideTimes ? VLCStyle.fontSize_small
                                        : VLCStyle.fontSize_normal
        text: {
            // This text metrics is used for both the time and length, as we want them to have the same width.
            // Length might not be reported in some cases, for that reason we should check both and use the bigger one.

            // Some extra space to compensate non-monospaced fonts ("-" takes more space than ":", double "-" for guarantee)
            return (Player.time.isSubHour() && Player.length.isSubHour()) ? "00--00" : "00--00--00"
        }
    }

    background: Rectangle {
        color: root.backgroundColor
    }

    contentItem: ColumnLayout {
        spacing: root._twoRows ? VLCStyle.dp(24, VLCStyle.scale) : VLCStyle.margin_xsmall

        readonly property real sliderY: row2.y

        property alias trackPositionSlider: trackPositionSlider

        property alias mediaRemainingTime: mediaRemainingTime

        property alias playerControlLayout: playerControlLayout

        readonly property list<Item> strayItems: [
            T.Label {
                id: mediaTime

                Layout.preferredWidth: root._sideTimes ? timeTextMetrics.width : -1

                text: {
                    if (root.editing && !Player.isStarted)
                        return "00:00"
                    const length = Player.length
                    return Player.time.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
                }
                color: root._compact ? theme.fg.secondary : theme.fg.primary
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaTime
                    property: "mutabilityGroup"
                    when: (mediaTime.mutabilityGroup !== undefined)
                    value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                  : Item.StaticMutabilityGroup
                }

                anchors.left: (parent === pseudoRow) ? parent.left : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined
            },
            T.Label {
                id: mediaRemainingTime

                Layout.preferredWidth: root._sideTimes ? timeTextMetrics.width : -1

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                text: (root.editing && !Player.isStarted) ? "00:00"
                      : showRemainingTime
                      ? "-" + Player.remainingTime.formatHMS()
                      : Player.length.formatHMS()
                color: mediaTime.color
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                visible: root.showRemainingTime

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaRemainingTime
                    property: "mutabilityGroup"
                    when: (mediaRemainingTime.mutabilityGroup !== undefined)
                    value: ((Player.playingState === Player.PLAYING_STATE_PLAYING) &&
                            mediaRemainingTime.showRemainingTime) ? Item.ModerateMutabilityGroup
                                                                  : Item.StaticMutabilityGroup
                }

                anchors.right: (parent === pseudoRow) ? parent.right : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined

                TapHandler {
                    enabled: !root.editing
                    onTapped: (eventPoint, button) => {
                        MainCtx.showRemainingTime = !MainCtx.showRemainingTime
                    }
                }

                HoverHandler {
                    id: mediaRemainingTimeHover
                }

                Widgets.ToolTipExt {
                    colorContext.palette: theme.palette

                    visible: mediaRemainingTimeHover.hovered && MainCtx.showRemainingTime && Player.rate !== 1
                    delay: VLCStyle.delayToolTipAppear
                    text: {
                        if (!visible)
                            return ""

                        const playbackSpeed = Math.abs(Player.rate)
                        const adjustedRemainingTime = Player.remainingTime.scale(1 / playbackSpeed)
                            ? Player.remainingTime.scale(1 / playbackSpeed)
                            : Player.remainingTime

                        return qsTr("%1 (%2x)")
                            .arg(adjustedRemainingTime.formatHMS())
                            .arg(+Player.rate.toFixed(2))
                    }

                    x: (parent.width - width) / 2
                }
            },
            SliderBar {
                id: trackPositionSlider

                barHeight: root.sliderHeight
                paintOnly: root.editing

                blockStyle: root._compact
                waveform: root.musicMode && root._compact
                waveformSource: waveformLoader.item

                Loader {
                    id: waveformLoader
                    // only once the tracks are known and are audio only: Player.url changes before the
                    // demuxer lists any track, so a video would otherwise be decoded for a moment.
                    // Not while stopping either: the video tracks go before the audio ones then.
                    active: trackPositionSlider.waveform && Player.audioTracks.count > 0 && Player.videoTracks.count === 0
                            && (Player.playingState === Player.PLAYING_STATE_PLAYING
                                || Player.playingState === Player.PLAYING_STATE_PAUSED)
                    sourceComponent: Waveform {
                        ctx: MainCtx
                        uri: Player.url
                    }
                }

                backgroundColor: !root._compact ? theme.bg.primary
                                                : root._dark ? "#090909" : Qt.darker(root.backgroundColor, 1.15)
                progressColor: root._compact ? Qt.tint(backgroundColor, Qt.alpha(theme.accent, root._dark ? 0.26 : 0.4))
                                             : theme.fg.primary

                Accessible.role: Accessible.Slider
                Accessible.name: qsTr("Progress")
                AccessibleCompat.id: "progressSlider"

                Layout.fillWidth: true
                enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                Navigation.parentItem: root
                Navigation.downItem: playerControlLayout

                activeFocusOnTab: !root.editing

                focus: true

                Keys.onPressed: (event) => {
                    Navigation.defaultKeyAction(event)
                }
            },
            Loader {
                id: bookmarksLoader

                parent: root
                active: MainCtx.mediaLibraryAvailable && (root._textPosition !== ControlBar.TimeTextPosition.Inline) && !root.editing
                source: "qrc:///qt/qml/VLC/MediaLibrary/Bookmarks.qml"

                x: root.leftPadding + trackPositionSlider.x + row2.Layout.leftMargin
                y: row2.y + row2.height + VLCStyle.margin_xxsmall
                width: trackPositionSlider.width

                onLoaded: {
                   item.barHeight = Qt.binding(function() { return bookmarksHeight })
                   item.controlBarHovered = Qt.binding(function() { return root.hovered })
                   item.yShift = Qt.binding(function() { return row2.height + VLCStyle.margin_xxsmall })
                }
            },
            // Customize Player: the seekbar as one item, over where it is drawn
            Item {
                id: seekItem

                readonly property bool inline: root._textPosition === ControlBar.TimeTextPosition.Inline

                parent: root
                z: 1
                visible: root.editing

                // the row's dashes stand 4 px off the bar (Figma 2160:6137)
                readonly property real _outset: inline ? 0 : VLCStyle.dp(4, VLCStyle.scale)

                x: root.leftPadding + (inline ? editRow.x + (editZones.item?.seekSlot.x ?? 0) : row2.x) - _outset
                y: root.topPadding + (inline ? editRow.y : row2.y) - _outset
                width: (inline ? (editZones.item?.seekSlot.width ?? 0) : row2.width) + _outset * 2
                height: (inline ? editRow.height : row2.height) + _outset * 2

                DashedBox {
                    anchors.fill: parent
                }

                MouseArea {
                    anchors.fill: parent

                    acceptedButtons: Qt.LeftButton
                    cursorShape: pressed ? Qt.DragMoveCursor : Qt.OpenHandCursor

                    drag.target: seekDrag
                    drag.smoothed: false

                    drag.onActiveChanged: {
                        if (drag.active) {
                            PlayerControlbarControls.customizeDragging = true
                            seekDrag.Drag.start()
                        } else {
                            // anywhere but the other place, it just stays
                            seekDrag.Drag.drop()
                            PlayerControlbarControls.customizeDragging = false
                        }
                    }

                    onPressed: {
                        const pos = mapToItem(seekDrag.parent, mouseX, mouseY)
                        seekDrag.x = pos.x + VLCStyle.dragDelta
                        seekDrag.y = pos.y + VLCStyle.dragDelta
                    }
                }

                // what follows the pointer; the drag's source for the zones
                Rectangle {
                    id: seekDrag

                    readonly property int controlId: ControlListModel.SEEKBAR

                    parent: Drag.active ? seekItem.Window.contentItem : seekItem
                    z: 1000
                    visible: Drag.active

                    width: VLCStyle.dp(240, VLCStyle.scale)
                    height: VLCStyle.dp(28, VLCStyle.scale)
                    color: "#090909"

                    Drag.source: seekDrag
                    Drag.hotSpot: Qt.point(-VLCStyle.dragDelta, -VLCStyle.dragDelta)

                    DashedBox {
                        anchors.fill: parent
                    }
                }
            }
        ]

        Item {
            // BUG: RowLayout can not be used here
            // because of a Qt bug. (Height is
            // incorrectly determined. Could be
            // about nested layouting).

            id: pseudoRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal

            implicitHeight: visible ? Math.max(mediaTime.implicitHeight, mediaRemainingTime.implicitHeight) : 0

            visible: children.length > 0

            children: {
                switch (root._textPosition) {
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [mediaTime, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.Inline:
                case ControlBar.TimeTextPosition.LeftRightSlider:
                default:
                    return []
                }
            }
        }

        RowLayout {
            id: row2

            children: {
                switch (root._textPosition) {
                case ControlBar.TimeTextPosition.Inline:
                    return []
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [trackPositionSlider]
                case ControlBar.TimeTextPosition.LeftRightSlider:
                    return [mediaTime, trackPositionSlider, mediaRemainingTime]
                default:
                    return []
                }
            }

            visible: children.length > 0

            spacing: VLCStyle.margin_xsmall

            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: root._twoRows ? VLCStyle.dp(24, VLCStyle.scale)
                             : (root._textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? VLCStyle.margin_xsmall
                                                                                                   : 0

            Layout.rightMargin: Layout.leftMargin
        }

        // Customize Player: while the seekbar is inline its own row stays free as the place to drop it (Figma 2107:5604)
        Item {
            id: seekRowZone

            visible: root.editing && (root._textPosition === ControlBar.TimeTextPosition.Inline)

            Layout.fillWidth: true
            Layout.preferredHeight: root.sliderHeight
            Layout.leftMargin: VLCStyle.dp(24, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(24, VLCStyle.scale)

            DashedBox {
                anchors.fill: parent
                anchors.margins: -VLCStyle.dp(4, VLCStyle.scale)
                visible: PlayerControlbarControls.customizeDragging
            }

            DropArea {
                anchors.fill: parent

                onEntered: (drag) => {
                    drag.accepted = drag.source?.controlId === ControlListModel.SEEKBAR
                }
                onDropped: (drop) => {
                    root.seekRowModel.left.insert(0, {"id": ControlListModel.SEEKBAR})
                    drop.accept(Qt.MoveAction)
                }
            }
        }

        // Parented into the controls row's spacer (see PlayerControlLayout.fillerItem)
        RowLayout {
            id: inlineRow

            parent: root.editing ? (editZones.item?.seekSlot ?? null) : playerControlLayout.fillerItem
            anchors.fill: parent ?? undefined
            anchors.leftMargin: root.editing ? VLCStyle.dp(8, VLCStyle.scale) : VLCStyle.dp(20, VLCStyle.scale)
            anchors.rightMargin: anchors.leftMargin

            spacing: VLCStyle.margin_xsmall

            visible: root._textPosition === ControlBar.TimeTextPosition.Inline
            children: visible ? [mediaTime, trackPositionSlider, mediaRemainingTime] : []
        }

        PlayerControlLayout {
            id: playerControlLayout

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root._compact ? VLCStyle.dp(20, VLCStyle.scale) : VLCStyle.margin_large
            Layout.rightMargin: root._compact ? VLCStyle.dp(20, VLCStyle.scale) : VLCStyle.margin_large

            spacing: root._compact ? VLCStyle.margin_xsmall : VLCStyle.margin_normal

            compactStyle: root._compact

            identifier: root.identifier

            // Figma compact bar: 32px row (28px pill) inside 11px padding = 54px
            implicitHeight: (root._compact || MainCtx.pinVideoControls) ? VLCStyle.controlLayoutHeightPinned
                                                                        : VLCStyle.controlLayoutHeight

            visible: !root.editing && (!model?.empty ?? false)

            Navigation.upItem: trackPositionSlider.enabled ? trackPositionSlider : root.Navigation.upItem

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: {
                root.forceUnlock.connect(playerControlLayout.forceUnlock)
            }
        }

        // Customize Player: the controls row's zones, in place of the controls
        Item {
            id: editRow

            visible: root.editing

            Layout.fillWidth: true
            Layout.preferredHeight: playerControlLayout.implicitHeight
            Layout.leftMargin: playerControlLayout.Layout.leftMargin
            Layout.rightMargin: playerControlLayout.Layout.rightMargin

            Loader {
                id: editZones

                anchors.fill: parent
                active: root.editing

                sourceComponent: Item {
                    readonly property alias seekSlot: seekSlot
                    readonly property bool seekInline: root._textPosition === ControlBar.TimeTextPosition.Inline
                    // beside an empty centre zone the free space reads as one (Figma 2160:6137)
                    readonly property bool centerEmpty: !seekInline && editCenter.count === 0

                    EditorDNDView {
                        id: editLeft

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.seekInline ? implicitWidth : editCenter.x

                        model: root._bottomModel?.left ?? null
                        compactStyle: root._compact
                        dashFreeSpace: !parent.seekInline
                        drawFreeSpace: !parent.centerEmpty
                    }

                    EditorDNDView {
                        id: editCenter

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width)
                        visible: !parent.seekInline

                        model: root._bottomModel?.center ?? null
                        alignment: Qt.AlignHCenter
                        compactStyle: root._compact
                        dashFreeSpace: false
                        emptyWidth: VLCStyle.dp(120, VLCStyle.scale)

                        acceptsSeekbar: true
                        onSeekbarDropped: root._moveSeekbarInline()
                    }

                    EditorDNDView {
                        id: editRight

                        x: parent.seekInline ? parent.width - width : editCenter.x + editCenter.width
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.seekInline ? implicitWidth : parent.width - x

                        model: root._bottomModel?.right ?? null
                        alignment: Qt.AlignRight
                        compactStyle: root._compact
                        dashFreeSpace: !parent.seekInline
                        drawFreeSpace: !parent.centerEmpty
                    }

                    DashedBox {
                        visible: parent.centerEmpty
                        anchors.verticalCenter: parent.verticalCenter
                        x: editLeft.listEnd
                        width: editRight.x + editRight.listStart - x
                        height: editCenter.height
                    }

                    Item {
                        id: seekSlot

                        readonly property real _gap: VLCStyle.dp(16, VLCStyle.scale)

                        visible: parent.seekInline
                        x: editLeft.width + _gap
                        width: editRight.x - _gap - x
                        height: parent.height
                    }
                }
            }
        }
    }
}
