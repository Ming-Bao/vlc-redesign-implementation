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

Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    implicitHeight: VLCStyle.dp(44, VLCStyle.scale)
    radius: VLCStyle.dp(6, VLCStyle.scale)
    color: _s.field

    RowLayout {
        anchors.fill: parent; anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
        spacing: VLCStyle.dp(2, VLCStyle.scale)
        Repeater {
            model: root.model
            T.Button {
                id: seg
                required property int index
                required property string modelData
                Layout.fillWidth: true; Layout.fillHeight: true
                text: modelData
                onClicked: root.activated(index)
                Accessible.name: modelData
                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: seg.index === root.currentIndex ? root._s.accentBg : root._s.face
                    border.width: seg.visualFocus ? VLCStyle.focus_border : 0
                    border.color: theme.visualFocus
                }
                contentItem: Widgets.LabelExt {
                    text: seg.text
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: seg.index === root.currentIndex ? root._s.accent : root._s.label
                }
            }
        }
    }
}
