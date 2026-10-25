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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// General's Theme: Dark / Light / System on MainCtx.colorScheme. The segments map to the model's Night / Day / System
// by scheme (the model's own order is System, Day, Night).
Item {
    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true

    readonly property var schemes: [ ColorSchemeModel.Night, ColorSchemeModel.Day, ColorSchemeModel.System ]

    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    Widgets.LabelExt {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.row.label
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: parent.delegate ? parent.delegate.style.rowLabel : "transparent"
    }

    SettingSegments {
        anchors.right: parent.right
        width: VLCStyle.dp(320, VLCStyle.scale)
        height: parent.height
        model: [ qsTr("Dark"), qsTr("Light"), qsTr("System") ]
        currentIndex: parent.schemes.indexOf(MainCtx.colorScheme.scheme)
        onActivated: (i) => MainCtx.colorScheme.setScheme(parent.schemes[i])
    }
}
