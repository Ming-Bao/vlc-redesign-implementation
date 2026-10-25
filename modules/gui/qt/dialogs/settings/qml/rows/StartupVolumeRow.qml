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

// Audio's Startup volume: Remember last volume (volume-save on), or Always starts at a fixed volume (volume-save off).
// VLC has no option for the fixed volume: the field shows 100% and is read-only (my call).
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property var style: delegate ? delegate.style : null
    readonly property bool remember: {
        void(delegate ? delegate.rev : 0)
        return !!SettingsBridge.value("volume-save")
    }

    spacing: VLCStyle.dp(4, VLCStyle.scale)

    component Choice: T.Button {
        id: btn

        required property bool selected
        property bool remembers: false
        property alias fieldText: field.text

        width: root.width
        implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
        onClicked: SettingsBridge.setValue("volume-save", btn.remembers)
        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: btn.selected ? root.style.accentBg : root.style.face
            border.width: btn.visualFocus ? VLCStyle.focus_border : 0
            border.color: root.style.accent
        }
        contentItem: Item {
            Widgets.LabelExt {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: btn.selected ? root.style.accent : root.style.label
            }
            Rectangle {
                visible: field.text.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(180, VLCStyle.scale)
                height: parent.height - VLCStyle.dp(4, VLCStyle.scale)
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root.style.field
                Widgets.LabelExt {
                    id: field
                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root.style.placeholder
                }
            }
        }
    }

    Choice {
        text: qsTr("Remember last volume")
        remembers: true
        selected: root.remember
    }

    Choice {
        text: qsTr("Always starts at:")
        fieldText: qsTr("100%")
        selected: !root.remember
    }
}
