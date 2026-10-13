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

// Figma queue card: stays open while watching (non-modal), fills the height beside the video
PlayerPanel {
    id: root

    tabs: [
        { text: qsTr("Queue"), icon: VLCIcons.playqueue }
    ]

    fillHeight: true
    modal: false
    dim: false

    // the page, for the player to wire keyboard navigation into the list and out of it
    readonly property alias page: queuePage

    QueuePage { id: queuePage }
}
