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

// Figma Sidebar 848:1995: the library beside the playing media, an icon rail
// plus the library pages, sharing the global History with MainDisplay
FocusScope {
    id: root

    property bool open: false

    // the LibraryPageLoader, for navigation (null until the panel first opens)
    readonly property Item content: pages.item

    // Escape at the history root: hand the focus back (the panel stays open)
    signal navigationCancel()

    clip: true // the pages' views draw past their ends (under the control bar)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // the pages are built on first open, not each time the player starts
    onOpenChanged: if (open) pages.active = true

    Navigation.cancelAction: function() {
        if (History.previousEmpty)
            root.navigationCancel()
        else
            History.previous(Qt.BacktabFocusReason)
    }

    // page area (Figma Dark/BG/B1 Transparent, 95 %); nothing is behind the
    // panel to blur, so the Figma's background blur is left out
    Rectangle {
        anchors.fill: parent
        color: theme.palette?.isDark ? Qt.rgba(0x0E / 255, 0x0E / 255, 0x0E / 255, 0.95)
                                     : theme.bg.primary
    }

    Loader {
        id: pages

        active: false

        // Figma page area: 20 padding. The pages already keep their own margins
        // (VLCStyle.dynamicAppMargins + layout_left_margin) from their edges and
        // their header has a 20 top padding, so on the left the loader slides
        // under the rail by the difference rather than adding 20 to them.
        // The right keeps the pages' own margin, so their scroll bar stays at
        // the panel's edge.
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: rail.right
            right: parent.right
            leftMargin: VLCStyle.dp(20, VLCStyle.scale) - VLCStyle.dynamicAppMargins(root.width)
                        - VLCStyle.layout_left_margin
        }

        focus: true

        sourceComponent: LibraryPageLoader {
            focus: true

            Navigation.parentItem: root
            Navigation.leftItem: rail
        }
    }

    SideNavigationPane {
        id: rail

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }

        // Figma: 50 wide, icon wrappers 30×32 at x 10, the first at y 8, 46 apart
        // (the delegates are 46 high with the 32 high background inset 7 / 4)
        width: VLCStyle.dp(50, VLCStyle.scale)
        delegateShowText: false
        useAcrylic: false
        topPadding: VLCStyle.dp(1, VLCStyle.scale)
        leftPadding: VLCStyle.dp(6, VLCStyle.scale)
        rightPadding: VLCStyle.dp(6, VLCStyle.scale)
        bottomPadding: VLCStyle.margin_small

        background: Rectangle {
            color: theme.palette?.isDark ? "#191919" : theme.bg.secondary // Figma Dark/BG/A4
        }

        Navigation.parentItem: root
        Navigation.rightItem: pages.item

        LibraryAddMenu {
            id: addMenu
            loader: pages.item
        }

        onItemClicked: (modelUri, item) => {
            if (modelUri[0] === "additem") {
                addMenu.popup(item, item.width, 0)
                return
            }

            pages.item?.openSection(modelUri)
        }
    }
}
