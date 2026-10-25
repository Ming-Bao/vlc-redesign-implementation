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

import "qrc:/qt/qml/VLC/Dialogs/SettingsData.js" as Data

TestCase {
    name: "SettingsData"

    function test_presetFor() {
        const d = [1000, 300, 1000, 300]
        compare(Data.presetFor([1000, 300, 1000, 300], d), "normal")
        compare(Data.presetFor([500, 150, 500, 150], d), "low")
        compare(Data.presetFor([2000, 600, 2000, 600], d), "high")
        compare(Data.presetFor([2000, 300, 1000, 300], d), "custom")
    }

    function test_search() {
        compare(Data.search(Data.pages, "").length, 0)
        compare(Data.search(Data.pages, "   ").length, 0)
        const r = Data.search(Data.pages, "DEVELOPER OPTIONS") // case, and an Advanced section title
        compare(r.length, 1); compare(r[0].title, "Global Settings")
        verify(Data.search(Data.pages, "(").length >= 0)      // no throw on regex characters
        compare(Data.search(Data.pages, "zzqq").length, 0)
        const p = Data.search(Data.pages, "proxy")
        compare(p[0].title, "Network Connections & Security")
    }
}
