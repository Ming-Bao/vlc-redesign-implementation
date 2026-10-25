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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// Audio's Equalizer toggle (`equalizer` in `audio-filter`), preset dropdown, and the band block: the preamp and ten
// band sliders with a dB field each. While the toggle is on the block shows, and its bar folds it. Everything is
// written to the config (`equalizer-preamp`, `equalizer-bands`, `equalizer-preset`), not to the running audio output.
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null

    readonly property int rev: (delegate ? delegate.rev : 0) + Effects.revision
    readonly property bool on: {
        void(rev)
        return SettingsBridge.listHas("audio-filter", "equalizer")
    }
    property bool folded: false
    // 0 = None (filter off), 1..n = the presets, n + 1 = Custom (the bands match no preset)
    readonly property var presetModel: [qsTr("None")].concat(Effects.equalizerPresets).concat([qsTr("Custom")])
    readonly property var vlcLabels: [qsTr("60 Hz"), qsTr("170 Hz"), qsTr("310 Hz"), qsTr("600 Hz"), qsTr("1 KHz"),
                                      qsTr("3 KHz"), qsTr("6 KHz"), qsTr("12 KHz"), qsTr("14 KHz"), qsTr("16 KHz")]
    readonly property var isoLabels: [qsTr("31 Hz"), qsTr("63 Hz"), qsTr("125 Hz"), qsTr("250 Hz"), qsTr("500 Hz"),
                                      qsTr("1 KHz"), qsTr("2 KHz"), qsTr("4 KHz"), qsTr("8 KHz"), qsTr("16 KHz")]
    // [label, value] of the preamp then the ten bands
    readonly property var bands: {
        void(rev)
        const labels = SettingsBridge.value("equalizer-vlcfreqs") ? vlcLabels : isoLabels
        const v = String(SettingsBridge.value("equalizer-bands")).split(/\s+/).filter((s) => s.length).map(Number)
        const out = [{ label: qsTr("Preamp"), value: Number(SettingsBridge.value("equalizer-preamp")) }]
        for (let i = 0; i < labels.length; ++i)
            out.push({ label: labels[i], value: Math.max(-20, Math.min(20, v[i] || 0)) })
        return out
    }
    readonly property real _lineHeight: VLCStyle.dp(46, VLCStyle.scale)
    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    function _setPreset(i) {
        if (i === 0) {
            SettingsBridge.setListHas("audio-filter", "equalizer", false)
            return
        }
        if (i > Effects.equalizerPresets.length)
            return
        const p = Effects.equalizerPresetValues(i - 1)
        SettingsBridge.setValue("equalizer-preamp", p.preamp)
        SettingsBridge.setValue("equalizer-bands", p.bands)
        SettingsBridge.setValue("equalizer-preset", p.name)
        SettingsBridge.setListHas("audio-filter", "equalizer", true)
    }

    // slot 0 is the preamp. A band edit leaves the preset (Custom).
    function _setBand(slot, db) {
        db = Math.max(-20, Math.min(20, Math.round(db * 10) / 10))
        if (slot === 0) {
            SettingsBridge.setValue("equalizer-preamp", db)
            return
        }
        const v = bands.slice(1).map((b) => b.value)
        v[slot - 1] = db
        SettingsBridge.setValue("equalizer-bands", v.map((x) => x.toFixed(1)).join(" "))
        SettingsBridge.setValue("equalizer-preset", "")
        SettingsBridge.setListHas("audio-filter", "equalizer", true)
    }

    onOnChanged: if (on) folded = false

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        SettingToggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.on
            onRequested: (on) => SettingsBridge.setListHas("audio-filter", "equalizer", on)
            Accessible.name: root.row.label
        }
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Equalizer preset")
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        SettingCombo {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root._controlWidth
            height: VLCStyle.dp(36, VLCStyle.scale)
            textPadding: VLCStyle.dp(14, VLCStyle.scale)
            model: root.presetModel
            currentIndex: {
                void(root.rev)
                if (!root.on)
                    return 0
                const p = Effects.equalizerPresetIndex()
                return p < 0 ? root.presetModel.length - 1 : p + 1
            }
            onActivated: (i) => root._setPreset(i)
            Accessible.name: qsTr("Equalizer preset")
        }
    }

    Rectangle {
        visible: root.on
        width: root.width
        height: visible ? panel.implicitHeight : 0
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root.style ? root.style.box : "transparent"

        Column {
            id: panel

            width: parent.width

            T.Button {
                id: bar

                width: parent.width
                implicitHeight: VLCStyle.dp(38, VLCStyle.scale)
                onClicked: root.folded = !root.folded
                Accessible.name: text
                text: root.folded ? qsTr("Open Equalizer") : qsTr("Close Equalizer")
                background: Rectangle {
                    color: "transparent"
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    border.width: bar.visualFocus ? VLCStyle.focus_border : 0
                    border.color: root.style.accent
                }
                contentItem: Item { Row {
                    spacing: VLCStyle.dp(8, VLCStyle.scale)
                    anchors.centerIn: parent
                    Widgets.LabelExt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.text
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: root.style.rowLabel
                    }
                    Widgets.IconLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: VLCIcons.expand
                        rotation: root.folded ? 0 : 180
                        font.pixelSize: VLCStyle.icon_normal
                        color: root.style.rowLabel
                    }
                } }
            }

            Row {
                id: sliders

                visible: !root.folded
                width: parent.width
                height: visible ? implicitHeight : 0
                topPadding: VLCStyle.dp(16, VLCStyle.scale)
                bottomPadding: VLCStyle.dp(16, VLCStyle.scale)

                Repeater {
                    model: 11   // fixed: a slider mid-drag must not be rebuilt

                    Column {
                        id: strip

                        required property int index
                        readonly property var modelData: root.bands[index]

                        width: sliders.width / 11
                        spacing: VLCStyle.dp(12, VLCStyle.scale)

                        T.Slider {
                            id: slider

                            anchors.horizontalCenter: parent.horizontalCenter
                            orientation: Qt.Vertical
                            implicitWidth: VLCStyle.dp(16, VLCStyle.scale)
                            implicitHeight: VLCStyle.dp(320, VLCStyle.scale)
                            from: -20
                            to: 20
                            stepSize: 0.1
                            snapMode: T.Slider.SnapAlways
                            value: strip.modelData.value
                            onMoved: root._setBand(strip.index, value)
                            Accessible.name: strip.modelData.label

                            background: Rectangle {
                                radius: VLCStyle.dp(6, VLCStyle.scale)
                                color: root.style.field
                                border.width: slider.visualFocus ? VLCStyle.focus_border : 0
                                border.color: root.style.accent

                                Rectangle {
                                    x: VLCStyle.dp(2, VLCStyle.scale)
                                    y: slider.handle.y + slider.handle.height / 2
                                    width: parent.width - 2 * x
                                    height: parent.height - VLCStyle.dp(2, VLCStyle.scale) - y
                                    radius: VLCStyle.dp(4, VLCStyle.scale)
                                    color: root.style.accentBg
                                }
                            }
                            handle: Rectangle {
                                x: (slider.width - width) / 2
                                y: slider.visualPosition * (slider.availableHeight - height)
                                implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                                implicitHeight: VLCStyle.dp(8, VLCStyle.scale)
                                radius: VLCStyle.dp(4, VLCStyle.scale)
                                color: root.style.accentDim
                            }
                        }

                        Widgets.LabelExt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: strip.modelData.label
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: root.style.label
                        }

                        SettingField {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitWidth: VLCStyle.dp(60, VLCStyle.scale)
                            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                            leftPadding: VLCStyle.dp(4, VLCStyle.scale)
                            rightPadding: VLCStyle.dp(4, VLCStyle.scale)
                            horizontalAlignment: TextInput.AlignHCenter
                            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                            suffix: qsTr(" dB")
                            validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }
                            committedText: strip.modelData.value.toFixed(1)
                            onCommitted: (t) => {
                                const v = parseFloat(t.replace(",", "."))
                                if (!isNaN(v))
                                    root._setBand(strip.index, v)
                            }
                            Accessible.name: strip.modelData.label
                        }
                    }
                }
            }
        }
    }
}
