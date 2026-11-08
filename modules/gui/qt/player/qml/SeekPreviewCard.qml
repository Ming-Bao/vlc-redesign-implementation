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
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

// Figma thumbnail 2151:9673: the frame at the hovered time above the seek bar
Item {
    id: root

    property alias uri: preview.uri
    property alias position: preview.position
    property string text

    function allowed() { return preview.allowed() }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
        palette: VLCStyle.palette   // parented to the window, outside any context
    }

    width: VLCStyle.dp(272, VLCStyle.scale)
    height: VLCStyle.dp(189, VLCStyle.scale)

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: Qt.alpha(theme.palette.tokens.bgA3, 0.95)
    }

    // before the first frame the picture area is the card fill
    SeekPreview {
        id: preview
        ctx: MainCtx
        x: VLCStyle.dp(10, VLCStyle.scale)
        y: VLCStyle.dp(10, VLCStyle.scale)
        width: VLCStyle.dp(252, VLCStyle.scale)
        height: VLCStyle.dp(142, VLCStyle.scale)
        radius: VLCStyle.dp(4, VLCStyle.scale)
    }

    Widgets.LabelExt {
        x: VLCStyle.dp(10, VLCStyle.scale)
        y: VLCStyle.dp(162, VLCStyle.scale)
        width: root.width - VLCStyle.dp(20, VLCStyle.scale)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.text
        font.pixelSize: VLCStyle.dp(15, VLCStyle.scale)
        font.weight: Font.Normal
        color: theme.palette.tokens.fgA2
    }
}
