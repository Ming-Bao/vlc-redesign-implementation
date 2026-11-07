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

    function rowsByOption() {               // first option of each row -> row
        const m = {}
        for (const p of Data.pages) for (const s of p.sections) for (const r of s.rows) {
            const k = r.option ?? r.list ?? r.component ?? r.action
            m[k] = m[k] ?? r
        }
        return m
    }
    function test_appliesValues() {
        for (const p of Data.pages) for (const s of p.sections) for (const r of s.rows)
            verify(r.applies === undefined || r.applies === "next" || r.applies === "restart", r.label)
    }
    function test_appliesSpot() {
        const m = rowsByOption()
        compare(m["dec-dev"].applies, "next")
        compare(m["sub-autodetect-file"].applies, "next")
        compare(m["aout"].applies, "next")
        compare(m["media-library"].applies, "restart")
        compare(m["file-logging"].applies, "restart")
        compare(m["qt-icon-change"].applies, "restart")
        compare(m["file-caching"].applies, "next")        // Buffering (custom row)
        compare(m["volume-save"].applies, "restart")      // Startup volume (custom row)
        compare(m["rate"].applies, undefined)
        compare(m["audio-track"].applies, undefined)
        compare(m["qt-max-volume"].applies, undefined)
        compare(m["freetype-color"].applies, undefined)
        compare(Data.appliesText(m["dec-dev"]), "Next video")
        compare(Data.appliesText(m["media-library"]), "After restart")
        compare(Data.appliesText(m["rate"]), "")
    }
    function test_deadRowsRemoved() {
        const m = rowsByOption()
        compare(m["qt-fs-sensitivity"], undefined)
        compare(m["playlist-tree"], undefined)
        verify(m["qt-fs-controller"] !== undefined)
        verify(m["qt-error-dialogs"] !== undefined)
    }
}
