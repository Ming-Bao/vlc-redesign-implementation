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

// Delay slider centred on 0 (Figma 1905:7352); the fill runs from the centre to the handle
ColumnLayout {
    id: root
    property int valueMs: 0
    signal movedMs(int ms)
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Slider; focused: slider.visualFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
    Layout.fillWidth: true
    spacing: VLCStyle.dp(10, VLCStyle.scale)

    T.Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: -10000; to: 10000; stepSize: 50
        snapMode: T.Slider.SnapAlways
        value: root.valueMs
        onMoved: {
            if (!resetGuard.running) root.movedMs(Math.round(value))
            else slider.value = Qt.binding(() => root.valueMs)   // drop the stray move, restore the handle
        }
        Accessible.name: qsTr("Delay")
        TapHandler { onDoubleTapped: { resetGuard.restart(); root.movedMs(0) } }
        // the slider also reports the second press as a move once the double tap has fired; drop that one
        Timer { id: resetGuard; interval: 150 }
        background: Rectangle {
            y: (slider.height - height) / 2
            width: slider.width; height: VLCStyle.dp(16, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale); color: root._s.field
            border.width: slider.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
            Rectangle {
                readonly property real c: parent.width / 2
                readonly property real h: slider.handle.x + slider.handle.width / 2
                x: Math.min(c, h); width: Math.abs(h - c)
                y: VLCStyle.dp(2, VLCStyle.scale); height: parent.height - 2 * y
                radius: VLCStyle.dp(4, VLCStyle.scale); color: root._s.accentBg
            }
        }
        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(8, VLCStyle.scale); implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale); color: root._s.accentDim
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Widgets.LabelExt { text: qsTr("-10 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
        Item { Layout.fillWidth: true }
        Widgets.LabelExt { text: qsTr("0 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
        Item { Layout.fillWidth: true }
        Widgets.LabelExt { text: qsTr("+10 s"); font.pixelSize: VLCStyle.dp(12, VLCStyle.scale); color: root._s.label }
    }
}
