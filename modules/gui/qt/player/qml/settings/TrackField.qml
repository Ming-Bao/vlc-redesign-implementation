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
import VLC.Player

// default-track field: shows "Auto" for -1, otherwise the 1-based track number; stores the 0-based index
SettingField {
    id: root
    required property string configName

    validator: IntValidator { bottom: -1; top: 99 }
    committedText: { void(Effects.revision); const n = Number(Effects.configValue(root.configName)); return n < 0 ? qsTr("Auto") : String(n + 1) }
    onCommitted: (t) => {
        if (t === "" || t === "-1" || t === qsTr("Auto")) { Effects.setConfigValue(root.configName, -1); return }
        const n = parseInt(t)
        if (!isNaN(n)) Effects.setConfigValue(root.configName, Math.max(0, n - 1))   // NaN (e.g. a lone "-") reverts
    }
}
