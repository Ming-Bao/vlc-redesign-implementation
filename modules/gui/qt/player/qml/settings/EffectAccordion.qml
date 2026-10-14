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
    property bool expanded: false
    default property alias content: body.data

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.Window }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    radius: VLCStyle.dp(6, VLCStyle.scale)
    color: expanded ? _s.box : _s.field

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        T.Button {
            id: header
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
            onClicked: root.expanded = !root.expanded
            Accessible.name: text
            text: root.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
            background: Rectangle {
                color: "transparent"; radius: root.radius
                border.width: header.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus
            }
            contentItem: RowLayout {
                Widgets.LabelExt {
                    Layout.fillWidth: true
                    leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                    text: header.text
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._s.label
                }
                // the same chevron as the combo box indicator: down when expanded, right when collapsed
                Widgets.IconLabel {
                    Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                    text: VLCIcons.expand
                    rotation: root.expanded ? 0 : -90
                    font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                    color: root._s.label
                }
            }
        }
        ColumnLayout {
            id: body
            visible: root.expanded
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
            Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
            spacing: VLCStyle.dp(5, VLCStyle.scale)
        }
    }
}
