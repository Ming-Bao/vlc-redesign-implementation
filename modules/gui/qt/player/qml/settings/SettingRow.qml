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

RowLayout {
    id: root
    property alias label: lbl.text
    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    // Figma: a row with a (non full width) combo is 63 tall, the 48 px control sitting on 15 px of padding: with the section's 5 px spacing
    // that is Figma's 68 px pitch
    // and the label centred on the control; the other rows are 48
    property bool _combo: false
    Layout.preferredHeight: VLCStyle.dp(_combo ? 63 : 48, VLCStyle.scale)
    spacing: VLCStyle.dp(12, VLCStyle.scale)

    function _scan() {
        for (let i = 0; i < children.length; ++i)
            if (children[i].fullWidth === false) {
                _combo = true
                return
            }
        _combo = false
    }
    onChildrenChanged: _scan()
    Component.onCompleted: _scan()

    Widgets.LabelExt {
        id: lbl
        Layout.fillWidth: true
        Layout.fillHeight: !root._combo
        Layout.preferredHeight: root._combo ? VLCStyle.dp(48, VLCStyle.scale) : -1
        Layout.alignment: Qt.AlignTop
        verticalAlignment: Text.AlignVCenter
        leftPadding: VLCStyle.dp(4, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root._s.label
        elide: Text.ElideRight
    }
}
