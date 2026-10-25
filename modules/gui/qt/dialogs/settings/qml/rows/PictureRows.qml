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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// Video's Picture block: the five adjust sliders on the options' own ranges, then Reset picture. Moving a slider off
// its default turns the `adjust` video filter on; Reset puts all five back and takes the filter off.
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null

    readonly property var sliders: [
        { label: qsTr("Hue"), option: "hue" },
        { label: qsTr("Brightness"), option: "brightness" },
        { label: qsTr("Contrast"), option: "contrast" },
        { label: qsTr("Saturation"), option: "saturation" },
        { label: qsTr("Gamma"), option: "gamma" }
    ]
    readonly property real _lineHeight: VLCStyle.dp(42, VLCStyle.scale)
    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    function _move(option, v) {
        SettingsBridge.setValue(option, v)
        if (Math.abs(v - SettingsBridge.defaultValue(option)) > 1e-6)
            SettingsBridge.setListHas("video-filter", "adjust", true)
    }

    function _reset() {
        for (const s of sliders)
            SettingsBridge.reset(s.option)
        SettingsBridge.setListHas("video-filter", "adjust", false)
    }

    Repeater {
        model: root.sliders

        Item {
            id: line

            required property var modelData
            readonly property var range: SettingsBridge.range(modelData.option)

            width: root.width
            height: root._lineHeight
            visible: SettingsBridge.exists(modelData.option)

            Widgets.LabelExt {
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.label
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root.style ? root.style.rowLabel : "transparent"
            }

            SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root._controlWidth
                showHeader: false
                label: line.modelData.label
                from: line.range.min ?? 0
                to: line.range.max ?? 1
                stepSize: (to - from) / 100
                value: {
                    void(root.delegate ? root.delegate.rev : 0)
                    return Number(SettingsBridge.value(line.modelData.option) ?? from)
                }
                defaultValue: Number(SettingsBridge.defaultValue(line.modelData.option) ?? from)
                onMoved: (v) => root._move(line.modelData.option, v)
            }
        }
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Reset picture")
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        FaceButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(100, VLCStyle.scale)
            text: qsTr("Reset")
            onClicked: root._reset()
        }
    }

    // the Figma's grey button (the delegate's own FaceButton isn't visible from here)
    component FaceButton: T.Button {
        id: btn

        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.style.face
            border.width: btn.visualFocus ? VLCStyle.focus_border : 0
            border.color: root.style.accent
        }
        contentItem: Widgets.LabelExt {
            text: btn.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            font.weight: Font.DemiBold
            color: root.style.rowLabel
        }
    }
}
