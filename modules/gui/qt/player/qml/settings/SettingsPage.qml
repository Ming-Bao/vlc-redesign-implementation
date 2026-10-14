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
import QtQuick.Layouts
import VLC.Style

// a settings tab's page: scrolls by itself because the gear card is full height
Flickable {
    id: root
    default property alias content: col.data
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + VLCStyle.dp(16, VLCStyle.scale)
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout { id: col; width: root.width; spacing: 0 }

    // keep keyboard focus visible
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const it = root.Window.activeFocusItem
            if (!it || !root.visible) return
            for (let p = it; p; p = p.parent)
                if (p === col) {
                    const r = it.mapToItem(col, 0, 0, it.width, it.height)
                    if (r.y < root.contentY) root.contentY = r.y
                    else if (r.y + r.height > root.contentY + root.height)
                        root.contentY = Math.min(r.y + r.height - root.height, root.contentHeight - root.height)
                    return
                }
        }
    }
}
