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

import "qrc:/qt/qml/VLC/Dialogs/HotkeysData.js" as Data

TestCase {
    name: "HotkeysData"

    readonly property var keys: ({ "key-toggle-fullscreen": "f", "key-leave-fullscreen": "Esc", "key-quit": "Ctrl+q" })
    function labelOf(row) { return row.label || row.option }
    function keysOf(row, global) { return global ? "" : (keys[row.option] || "") }
    function count(sections) { return sections.reduce((n, s) => n + s.rows.length, 0) }

    function test_sections() {
        compare(Data.sections[0].title, "Basic")
        compare(Data.sections[1].title, "Playback")
        compare(Data.sections[0].rows[0].label, "Toggle fullscreen")
    }
    function test_filterHotkey() {
        const r = Data.filter(Data.sections, labelOf, keysOf, "esc", "hotkey")
        compare(count(r), 1)
        compare(r[0].rows[0].option, "key-leave-fullscreen")
    }
    function test_filterActionIgnoresKeys() {
        compare(count(Data.filter(Data.sections, labelOf, keysOf, "esc", "action")), 0)
        verify(count(Data.filter(Data.sections, labelOf, keysOf, "fullscreen", "action")) >= 2)
    }
    function test_filterGlobalAndRegexChars() {
        compare(count(Data.filter(Data.sections, labelOf, keysOf, "esc", "global")), 0)
        Data.filter(Data.sections, labelOf, keysOf, "(", "all")
        compare(Data.filter(Data.sections, labelOf, keysOf, "", "all"), Data.sections)
    }
}
