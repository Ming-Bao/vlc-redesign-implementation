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

ColumnLayout {
    id: root
    property alias label: lbl.text
    property alias valueText: val.text
    property bool showHeader: true
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property real defaultValue: from
    property int ticks: 0          // number of tick marks including both ends; 0 = none
    signal moved(real v)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Slider; focused: slider.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    spacing: VLCStyle.dp(5, VLCStyle.scale)
    Layout.fillWidth: true

    RowLayout {
        visible: root.showHeader
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(10, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(5, VLCStyle.scale)
        Widgets.LabelExt { id: lbl; Layout.fillWidth: true; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: root._s.label }
        Widgets.LabelExt { id: val; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: root._s.label }
    }

    T.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: root.from; to: root.to; stepSize: root.stepSize
        snapMode: root.stepSize > 0 ? T.Slider.SnapAlways : T.Slider.NoSnap
        value: root.value
        onMoved: root.moved(value)
        Accessible.name: root.label

        TapHandler { acceptedButtons: Qt.LeftButton; onDoubleTapped: root.moved(root.defaultValue) }

        background: Rectangle {
            y: (slider.height - height) / 2
            width: slider.width; height: VLCStyle.dp(16, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.field
            border.width: slider.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus

            Rectangle {   // fill up to the handle
                x: VLCStyle.dp(2, VLCStyle.scale); y: x
                width: Math.max(0, slider.handle.x + slider.handle.width - x)
                height: parent.height - 2 * y
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root._s.accentBg
            }
            Repeater {
                model: root.ticks
                Rectangle {
                    required property int index
                    x: VLCStyle.dp(2, VLCStyle.scale) + index / (root.ticks - 1) * (parent.width - VLCStyle.dp(4, VLCStyle.scale))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: VLCStyle.dp(6, VLCStyle.scale)
                    color: root._s.tick
                }
            }
        }
        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(8, VLCStyle.scale); implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root._s.accentDim
        }
    }
}
