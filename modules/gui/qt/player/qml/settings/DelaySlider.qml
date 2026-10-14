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
import QtQuick.Layouts
import VLC.Style
import VLC.Widgets as Widgets

// Delay slider centred on 0 (Figma 1905:7352), with the -10 s / 0 s / +10 s scale below
ColumnLayout {
    id: root
    property int valueMs: 0
    signal movedMs(int ms)
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Slider }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }
    Layout.fillWidth: true
    spacing: VLCStyle.dp(10, VLCStyle.scale)

    SettingSlider {
        label: qsTr("Delay")
        showHeader: false
        centred: true
        from: -10000; to: 10000; stepSize: 50; defaultValue: 0
        value: root.valueMs
        onMoved: (v) => root.movedMs(Math.round(v))
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
