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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// Subtitles' Size values (Relative / Pixels) and Font size: a `freetype-rel-fontsize` dropdown for Relative, a
// `freetype-fontsize` field for Pixels. Pixels is on while `freetype-fontsize` is not 0; Relative writes it as 0.
// Both options are obsolete in VLC 4, so the row hides itself (`available`) in such a build.
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null
    readonly property bool available: SettingsBridge.exists("freetype-fontsize") && SettingsBridge.exists("freetype-rel-fontsize")

    // Pixels picked while the size is still 0
    property bool pickedPixels: false
    readonly property int pixels: {
        void(delegate ? delegate.rev : 0)
        return available ? Number(SettingsBridge.value("freetype-fontsize")) : 0
    }
    readonly property bool inPixels: pixels !== 0 || pickedPixels
    readonly property int defaultPixels: 24     // what Pixels starts at (my call)
    readonly property real _lineHeight: VLCStyle.dp(46, VLCStyle.scale)
    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    visible: available
    height: available ? implicitHeight : 0

    function _pick(i) {
        pickedPixels = i === 1
        SettingsBridge.setValue("freetype-fontsize", i === 1 ? defaultPixels : 0)
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Size values")
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        SettingSegments {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root._controlWidth
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            model: [ qsTr("Relative"), qsTr("Pixels") ]
            currentIndex: root.inPixels ? 1 : 0
            onActivated: (i) => root._pick(i)
        }
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        Loader {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root._controlWidth
            sourceComponent: root.inPixels ? pixelField : relative
        }
    }

    Component {
        id: relative

        SettingCombo {
            readonly property var list: root.available ? SettingsBridge.choices("freetype-rel-fontsize") : []

            height: VLCStyle.dp(36, VLCStyle.scale)
            textPadding: VLCStyle.dp(14, VLCStyle.scale)
            textRole: "label"
            model: list
            currentIndex: {
                void(root.delegate ? root.delegate.rev : 0)
                const v = String(SettingsBridge.value("freetype-rel-fontsize"))
                return list.findIndex((c) => String(c.value) === v)
            }
            onActivated: (i) => SettingsBridge.setValue("freetype-rel-fontsize", list[i].value)
            Accessible.name: root.row.label
        }
    }

    Component {
        id: pixelField

        SettingField {
            suffix: qsTr(" px")
            committedText: String(root.pixels)
            onCommitted: (t) => {
                const n = Number(t)
                if (t.length && !isNaN(n) && n > 0)
                    SettingsBridge.setValue("freetype-fontsize", Math.round(n))
            }
            Accessible.name: root.row.label
        }
    }
}
