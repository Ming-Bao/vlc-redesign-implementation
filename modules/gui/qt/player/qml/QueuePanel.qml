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
        { text: qsTr("Queue"), icon: VLCIcons.playqueue },
        { text: qsTr("Bookmarks"), icon: VLCIcons.bookmark },
        { text: qsTr("Chapters"), icon: VLCIcons.chapters }
    ]

    fillHeight: true
    modal: false
    dim: false

    // where keyboard navigation leaves the card, forwarded to every page (wired by the player)
    property Item navigationParent: null
    property Item navigationUp: null
    property Item navigationDown: null
    signal navigationCancel()

    // the shown tab's list, for the player to navigate into
    readonly property Item currentList: [queuePage, bookmarksPage, chaptersPage][currentTab]?.list ?? null

    QueuePage {
        id: queuePage
        navigationParent: root.navigationParent
        navigationUp: root.navigationUp
        navigationDown: root.navigationDown
        onNavigationCancel: root.navigationCancel()
    }

    BookmarksPage {
        id: bookmarksPage
        navigationParent: root.navigationParent
        navigationUp: root.navigationUp
        navigationDown: root.navigationDown
        onNavigationCancel: root.navigationCancel()
    }

    ChaptersPage {
        id: chaptersPage
        navigationParent: root.navigationParent
        navigationUp: root.navigationUp
        navigationDown: root.navigationDown
        onNavigationCancel: root.navigationCancel()
    }
}
