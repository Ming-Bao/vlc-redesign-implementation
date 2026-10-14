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

// hex colour field with a swatch inside; only a full #RRGGBB (the # is optional) is written, anything else reverts
SettingField {
    id: root
    required property string colorVar
    // true: the value is live on the running filter (Effects.value/setValue); false: the config only
    property bool live: false

    validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{0,6}/ }
    committedText: {
        void(Effects.revision)
        const v = root.live ? Effects.value(root.colorVar) : Effects.configValue(root.colorVar)
        return "#" + Number(v).toString(16).toUpperCase().padStart(6, "0")
    }
    onCommitted: (t) => {
        if (!/^#?[0-9A-Fa-f]{6}$/.test(t)) return
        const c = t.startsWith("#") ? t : "#" + t
        if (root.live) Effects.setValue(root.colorVar, c); else Effects.setConfigValue(root.colorVar, c)
    }
    Rectangle {   // swatch
        anchors.right: parent.right; anchors.rightMargin: VLCStyle.dp(6, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter
        width: VLCStyle.dp(22, VLCStyle.scale); height: width; radius: VLCStyle.dp(4, VLCStyle.scale)
        color: root.committedText
        border.width: 1; border.color: "#404040"
    }
}
