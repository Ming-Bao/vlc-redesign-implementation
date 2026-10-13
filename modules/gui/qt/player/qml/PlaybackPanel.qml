
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

    readonly property color _labelColor: _dark ? "#6B6B6B" : colorContext.fg.secondary
    readonly property color _fieldColor: _dark ? "#090909" : colorContext.bg.secondary
    readonly property color _valueColor: _dark ? "#8F8F8F" : colorContext.fg.primary

    readonly property real _minRate: 0.25
    readonly property real _maxRate: 2

    tabs: [ { text: qsTr("Playback"), icon: VLCIcons.effect_filter } ]

    footerText: qsTr("Effects and Filters")
    onFooterClicked: {
        root.close()
        DialogsProvider.extendedDialog()
    }

    component SettingRow : RowLayout {
        property alias label: lbl.text
        property color labelColor

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(52, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.dp(24, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Widgets.LabelExt {
            id: lbl
            Layout.fillWidth: true
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: parent.labelColor
        }
    }

    ColumnLayout {
        spacing: 0

        Item { Layout.preferredHeight: VLCStyle.dp(12, VLCStyle.scale) }

        SettingRow {
            label: qsTr("Reverse")
            labelColor: root._labelColor

            T.Switch {
                id: reverseSwitch

                readonly property ColorContext colorContext: ColorContext {
                    id: reverseSwitchTheme
                    colorSet: ColorContext.Switch
                    focused: reverseSwitch.visualFocus
                }

                implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                checked: Player.rate < 0
                onToggled: {
                    Player.reverse()
                    // most inputs refuse a negative rate: keep showing the real state
                    checked = Qt.binding(() => Player.rate < 0)
                }
                Accessible.name: qsTr("Reverse")

                indicator: Rectangle {
                    anchors.fill: parent
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._fieldColor
                    border.width: reverseSwitch.visualFocus ? VLCStyle.focus_border : 0
                    border.color: reverseSwitchTheme.visualFocus

                    Rectangle {
                        x: reverseSwitch.checked ? parent.width - width - VLCStyle.dp(2, VLCStyle.scale)
                                                 : VLCStyle.dp(2, VLCStyle.scale)
                        y: VLCStyle.dp(2, VLCStyle.scale)
                        width: parent.height - VLCStyle.dp(4, VLCStyle.scale)
                        height: width
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: reverseSwitch.checked ? root.colorContext.accent : "#3A3A3A"
                    }

                    Widgets.LabelExt {
                        x: reverseSwitch.checked ? VLCStyle.dp(10, VLCStyle.scale)
                                                 : parent.width - width - VLCStyle.dp(8, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: reverseSwitch.checked ? qsTr("ON") : qsTr("OFF")
                        font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                        color: root._valueColor
                    }
                }
            }
        }

        SettingRow {
            label: qsTr("Audio Visualizer")
            labelColor: root._labelColor

            Widgets.ComboBoxExt {
                id: visCombo

                Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
                model: Player.audioVisualization
                textRole: "display"
                color: root._valueColor

                // Figma field: #191919 inside a 4 px #090909 frame, regular 14 px text
                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._dark ? "#191919" : root.colorContext.bg.primary
                    border.width: visCombo.visualFocus ? VLCStyle.focus_border : VLCStyle.dp(4, VLCStyle.scale)
                    border.color: visCombo.visualFocus ? visCombo.colorContext.visualFocus : root._fieldColor
                }

                contentItem: Widgets.LabelExt {
                    leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                    rightPadding: visCombo.indicator.width + VLCStyle.dp(16, VLCStyle.scale)
                    text: visCombo.displayText
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._valueColor
                }

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
            labelColor: root._labelColor

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
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(16, VLCStyle.scale)

            from: root._minRate
            to: root._maxRate
            stepSize: 0.05
            value: Math.abs(Player.rate)
            onMoved: Player.rate = (Player.rate < 0 ? -value : value)
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
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
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
