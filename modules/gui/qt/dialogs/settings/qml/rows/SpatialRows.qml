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

// Audio's Spatial audio toggle and mode dropdown. The mode picks the module the toggle puts in `audio-filter`:
// Headphone virtualization = `headphone`, Room = `spatializer`. Changing the mode while on swaps the module.
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null

    readonly property var modules: ["headphone", "spatializer"]
    // the mode shown while the filter is off
    property int pickedMode: 0
    readonly property bool on: {
        void(delegate ? delegate.rev : 0)
        return modules.some((m) => SettingsBridge.listHas("audio-filter", m))
    }
    // on: the mode in the list; off: the one picked
    readonly property int mode: {
        void(delegate ? delegate.rev : 0)
        for (let i = 0; i < modules.length; ++i)
            if (SettingsBridge.listHas("audio-filter", modules[i]))
                return i
        return pickedMode
    }
    readonly property real _lineHeight: VLCStyle.dp(46, VLCStyle.scale)
    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    function _apply(on, m) {
        for (let i = 0; i < modules.length; ++i)
            SettingsBridge.setListHas("audio-filter", modules[i], on && i === m)
    }

    function _setMode(i) {
        pickedMode = i
        if (on)
            _apply(true, i)
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

        SettingToggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.on
            onRequested: (on) => root._apply(on, root.mode)
            Accessible.name: root.row.label
        }
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Spatial audio mode")
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        SettingCombo {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root._controlWidth
            height: VLCStyle.dp(36, VLCStyle.scale)
            textPadding: VLCStyle.dp(14, VLCStyle.scale)
            model: [ qsTr("Headphone virtualization"), qsTr("Room") ]
            currentIndex: root.mode
            onActivated: (i) => root._setMode(i)
            Accessible.name: qsTr("Spatial audio mode")
        }
    }
}
