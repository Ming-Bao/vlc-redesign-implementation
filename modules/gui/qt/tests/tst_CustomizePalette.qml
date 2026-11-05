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
import QtTest

import VLC.PlayerControls

import "qrc:/qt/qml/VLC/Dialogs/CustomizePalette.js" as Palette

TestCase {
    name: "CustomizePalette"

    function test_order_and_filter() {
        compare(Palette.items[0].label, "Spacer")
        compare(Palette.items[1].label, "Divider")
        verify(!Palette.items.some(i => i.label === "HDR"))
        verify(!Palette.items.some(i => i.id === ControlListModel.SEEKBAR))
        const placed = [ControlListModel.FAVORITE_BUTTON, ControlListModel.WIDGET_SPACER]
        const left = Palette.available(Palette.items, placed)
        verify(!left.some(i => i.id === ControlListModel.FAVORITE_BUTTON))   // frame 6587:19923
        verify(left.some(i => i.id === ControlListModel.WIDGET_SPACER))      // repeats stay
        // the order holds after a removal
        const stop = left.findIndex(i => i.label === "Stop")
        compare(left[stop + 1].label, "Repeat")
    }

    function test_figma_order_then_title_bar() {
        const labels = Palette.items.map(i => i.label)
        compare(labels.indexOf("Playlists"), 29)                             // the Figma's 31 without HDR
        compare(labels.slice(30, 37), ["More", "Library Sidebar", "Folder", "Title", "Minimize", "Maximize", "Close"])
    }

    function test_nothing_placed_stays_lost() {
        // what the default bars hold comes back after being dragged off (Save, then a new session)
        for (const id of [ControlListModel.PLAY_BUTTON, ControlListModel.PREVIOUS_BUTTON, ControlListModel.NEXT_BUTTON,
                          ControlListModel.VOLUME, ControlListModel.LANG_BUTTON, ControlListModel.EXTENDED_BUTTON,
                          ControlListModel.PLAYLIST_BUTTON, ControlListModel.FULLSCREEN_BUTTON])
            verify(Palette.items.some(i => i.id === id))
    }
}
