
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
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// Figma playback panel: reverse, audio visualizer, speed
PlayerPanel {
    id: root

    readonly property color _fieldColor: _dark ? "#090909" : colorContext.bg.secondary
    readonly property color _valueColor: _dark ? "#8F8F8F" : colorContext.fg.primary

    readonly property real _minRate: 0.25
    readonly property real _maxRate: 2

    fillHeight: true
    tabs: [
        { text: qsTr("Playback"),  icon: VLCIcons.effect_filter },
        { text: qsTr("Video"),     icon: VLCIcons.topbar_video, width: 85 },
        { text: qsTr("Audio"),     icon: VLCIcons.topbar_music, width: 85 },
        { text: qsTr("Subtitles"), icon: VLCIcons.audiosub }
    ]

    // values can change while the panel is closed (hotkeys, Preferences, the legacy dialog): re-read on open
    onOpened: Effects.refresh()
    // only stop a scan the Render popup started
    onClosed: if (videoPage.scanStarted) { videoPage.scanStarted = false; Player.rendererManager.StopScan() }

    footerHeader: T.Button {
        id: presetBtn

        readonly property SettingsStyle _s: SettingsStyle { theme: root.colorContext }
        readonly property ColorContext colorContext: ColorContext {
            id: presetTheme
            colorSet: ColorContext.ButtonStandard
            focused: presetBtn.visualFocus
        }

        visible: root.currentTab > 0
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(42, VLCStyle.scale)
        padding: VLCStyle.dp(2, VLCStyle.scale)
        text: qsTr("Default Preset")
        focusPolicy: Qt.StrongFocus
        onClicked: presetMenu.open()
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: presetBtn._s.field
            border.width: presetBtn.visualFocus ? VLCStyle.focus_border : 0
            border.color: presetTheme.visualFocus
        }

        contentItem: RowLayout {
            Widgets.LabelExt {
                Layout.fillWidth: true
                leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                text: presetBtn.text
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: presetBtn._s.value
            }
            Widgets.IconLabel {
                Layout.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
                text: VLCIcons.expand
                rotation: 180   // the glyph points down; the menu opens upwards
                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                color: presetBtn._s.value
            }
        }

        // a one-entry popup rather than a T.Menu: it stacks over the modal card like any other popup
        T.Popup {
            id: presetMenu
            y: -height - VLCStyle.dp(4, VLCStyle.scale)
            width: presetBtn.width
            height: VLCStyle.dp(38, VLCStyle.scale)
            padding: 0
            closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
            focus: true

            // keyboard: the entry takes focus on open; focus returns to the button on close
            onOpened: resetItem.forceActiveFocus(Qt.TabFocusReason)
            onClosed: presetBtn.forceActiveFocus(Qt.TabFocusReason)

            background: Rectangle { color: presetBtn._s.field; radius: VLCStyle.dp(6, VLCStyle.scale) }

            contentItem: T.ItemDelegate {
                id: resetItem
                implicitHeight: VLCStyle.dp(38, VLCStyle.scale)
                text: qsTr("Reset to Default Preset")
                readonly property bool _lit: hovered || visualFocus

                onClicked: {
                    presetMenu.close()
                    // the page that is showing resets itself: no tab index to keep in step
                    root.currentPage?.resetToDefaults?.()
                }
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()

                contentItem: Widgets.LabelExt {
                    leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: resetItem.text
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: resetItem._lit ? presetBtn._s.accent : presetBtn._s.value
                }
                background: Rectangle {
                    color: resetItem._lit ? presetBtn._s.face : "transparent"
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                }
            }
        }
    }

    footerFlat: true
    footerIcon: VLCIcons.settings
    footerText: qsTr("Open Advanced Settings")
    onFooterClicked: {
        root.close()
        DialogsProvider.prefsDialog()
    }

    SettingsPage {
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            spacing: VLCStyle.dp(5, VLCStyle.scale)

            Item { Layout.preferredHeight: VLCStyle.dp(12, VLCStyle.scale) }

            SettingRow {
                label: qsTr("Reverse")

                SettingToggle {
                    checked: Player.rate < 0
                    onRequested: Player.reverse()
                    Accessible.name: qsTr("Reverse")
                }
            }

            SettingRow {
                label: qsTr("Audio Visualizer")

                SettingCombo {
                    id: visCombo

                    model: Player.audioVisualization
                    textRole: "display"

                    // re-read whenever the panel opens; the model has no "current index" property
                    currentIndex: {
                        void(root.opened)
                        for (let i = 0; i < model.rowCount(); ++i)
                            if (model.data(model.index(i, 0), Qt.CheckStateRole))
                                return i
                        return 0
                    }
                    onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
                }
            }

            SettingRow {
                label: qsTr("Speed")

                Widgets.LabelExt {
                    Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)
                    Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
                    leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("%1x").arg(+Math.abs(Player.rate).toFixed(2))
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._valueColor
                    background: Rectangle { color: root._fieldColor; radius: VLCStyle.dp(4, VLCStyle.scale) }
                }
            }

            T.Slider {
                id: speedSlider

                readonly property ColorContext colorContext: ColorContext {
                    id: speedSliderTheme
                    colorSet: ColorContext.Slider
                    focused: speedSlider.visualFocus
                }

                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(16, VLCStyle.scale)

                from: root._minRate
                to: root._maxRate
                stepSize: 0.05
                snapMode: T.Slider.SnapAlways
                value: Math.abs(Player.rate)
                onMoved: Player.rate = (Player.rate < 0 ? -1 : 1) * Math.round(value * 100) / 100
                Accessible.name: qsTr("Playback speed")

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._fieldColor
                    border.width: speedSlider.visualFocus ? VLCStyle.focus_border : 0
                    border.color: speedSliderTheme.visualFocus

                    Rectangle {
                        width: speedSlider.handle.x + speedSlider.handle.width / 2
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(root.colorContext.accent, 0.4)
                    }

                    Repeater {
                        model: 6   // inner ticks at 0.5 … 1.75

                        Rectangle {
                            required property int index
                            x: speedSlider.leftPadding + (index + 1) / 7 * speedSlider.availableWidth
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: VLCStyle.dp(6, VLCStyle.scale)
                            color: "#3A3A3A"
                        }
                    }
                }

                handle: Rectangle {
                    x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                    implicitWidth: VLCStyle.dp(8, VLCStyle.scale)
                    implicitHeight: VLCStyle.dp(22, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    radius: VLCStyle.dp(2, VLCStyle.scale)
                    color: root.colorContext.accent
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.dp(12, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(16, VLCStyle.scale)

                Repeater {
                    model: 8   // 0.25 … 2

                    Widgets.LabelExt {
                        required property int index
                        x: index / 7 * parent.width - (index === 0 ? 0 : index === 7 ? width : width / 2)
                        text: +(0.25 * (index + 1))
                        font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                        color: root._valueColor
                    }
                }
            }
        }
    }

    VideoSettingsPage { id: videoPage }
    AudioSettingsPage {}
    SubtitleSettingsPage {}
}
