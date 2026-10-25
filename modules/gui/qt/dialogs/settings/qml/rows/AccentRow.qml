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

// General's Accent colour: nine swatches. The first (the default orange) writes `default`, the others their hex, to
// qt-accent-color. The palette reads the option once: the accent applies on the next launch (my call).
Item {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true

    readonly property var swatches: [ "#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3", "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF" ]
    readonly property string current: {
        void(delegate ? delegate.rev : 0)
        const v = String(SettingsBridge.value("qt-accent-color") ?? "default")
        return v === "default" ? swatches[0] : v.toUpperCase()
    }

    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    Widgets.LabelExt {
        anchors.verticalCenter: parent.verticalCenter
        text: root.row.label
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: root.delegate ? root.delegate.style.rowLabel : "transparent"
    }

    Rectangle {
        anchors.right: parent.right
        width: VLCStyle.dp(320, VLCStyle.scale)
        height: parent.height
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root.delegate ? root.delegate.style.field : "transparent"

        Row {
            anchors.fill: parent
            anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
            spacing: VLCStyle.dp(4, VLCStyle.scale)

            Repeater {
                model: root.swatches

                T.Button {
                    id: swatch

                    required property int index
                    required property string modelData
                    readonly property bool selected: modelData === root.current
                    readonly property color color: modelData

                    width: (parent.width - 8 * parent.spacing) / 9
                    height: parent.height
                    opacity: selected ? 1.0 : 0.7
                    padding: VLCStyle.dp(6, VLCStyle.scale)
                    onClicked: SettingsBridge.setValue("qt-accent-color", index === 0 ? "default" : modelData)
                    Accessible.name: modelData
                    Accessible.checked: selected

                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: !root.delegate ? "transparent"
                               : swatch.selected ? Qt.rgba(swatch.color.r * 0.26, swatch.color.g * 0.26, swatch.color.b * 0.26, 1)   // as SettingsStyle.accentBg
                               : root.delegate.style.face
                        border.width: swatch.visualFocus ? VLCStyle.focus_border : 0
                        border.color: root.delegate ? root.delegate.style.accent : "transparent"
                    }
                    contentItem: Rectangle {
                        radius: VLCStyle.dp(1, VLCStyle.scale)
                        color: swatch.color
                    }
                }
            }
        }
    }
}
