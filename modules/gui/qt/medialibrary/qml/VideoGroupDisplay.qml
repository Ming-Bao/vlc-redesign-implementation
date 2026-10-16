/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Menus

Widgets.PageExt {

    id: root

    property alias currentIndex: videoAll.currentIndex

    // restored from the navigation history (see VideoAllDisplay)
    property alias initialIndex: videoAll.initialIndex

    // NOTE: This is used to determine which media(s) shall be displayed.
    property alias parentId: modelVideo.parentId

    title: qsTr("Videos")

    // NOTE: the grouping choices of the old video sort menu, kept after the sort rows
    sortExtraRows: [
        { text: qsTr("Do not group videos"), checked: MainCtx.grouping === MainCtx.GROUPING_NONE,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_NONE } },
        { text: qsTr("Group by name"), checked: MainCtx.grouping === MainCtx.GROUPING_NAME,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_NAME } },
        { text: qsTr("Group by folder"), checked: MainCtx.grouping === MainCtx.GROUPING_FOLDER,
          run: () => { MainCtx.grouping = MainCtx.GROUPING_FOLDER } }
    ]

    VideoAll {
        id: videoAll

        // Aliases

        anchors.fill: parent

        focus: true

        displayMarginBeginning: root.displayMarginBeginning
        displayMarginEnd: root.displayMarginEnd
        enableBeginningFade: root.enableBeginningFade
        enableEndFade: root.enableEndFade

        sectionProperty: {
            switch (model.sortCriteria) {
            case "title":
                return "title_first_symbol"
            default:
                return ""
            }
        }

        function isInfoExpandPanelAvailable(/* modelIndexData */) {
            return true
        }

        // Children

        model: MLVideoModel {
            id: modelVideo

            searchPattern: root.search.pattern
            sortOrder: root.sort.order
            sortCriteria: root.sort.criteria

            ml: MediaLib
        }

        contextMenu: MLContextMenu { model: modelVideo; showPlayAsAudioAction: true }

    }
}
