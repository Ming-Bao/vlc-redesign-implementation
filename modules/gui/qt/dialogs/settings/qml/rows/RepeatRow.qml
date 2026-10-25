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
import VLC.Player
import VLC.Dialogs

// Playback's Repeat: one dropdown over two options, One = `repeat`, All = `loop`, Off = neither.
Item {
    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style

    // 0 Off, 1 One, 2 All
    readonly property int mode: {
        void(delegate ? delegate.rev : 0)
        // core starts with `repeat` (current) before `loop` (all); `repeat` is a bool, so an old player build's 2 reads as 1
        return SettingsBridge.value("repeat") ? 1 : SettingsBridge.value("loop") ? 2 : 0
    }

    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    SettingCombo {
        anchors.fill: parent
        textPadding: VLCStyle.dp(14, VLCStyle.scale)
        model: [ qsTr("Off"), qsTr("One"), qsTr("All") ]
        currentIndex: parent.mode
        onActivated: (i) => {
            SettingsBridge.setValue("repeat", i === 1)
            SettingsBridge.setValue("loop", i === 2)
        }
        Accessible.name: parent.row.label
    }
}
