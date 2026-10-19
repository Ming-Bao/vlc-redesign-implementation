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
import VLC.Util

TestCase {
    name: "LibraryHelpers"

    function test_sortRowLabel_data() {
        return [
            { tag: "title", criteria: "title", asc: "Title A-Z", desc: "Title Z-A" },
            { tag: "name", criteria: "name", asc: "Title A-Z", desc: "Title Z-A" },
            { tag: "album_title", criteria: "album_title", asc: "Album A-Z", desc: "Album Z-A" },
            { tag: "release_year", criteria: "release_year", asc: "Oldest First", desc: "Newest First" },
            { tag: "duration", criteria: "duration", asc: "Shortest First", desc: "Longest First" },
            { tag: "last_played_date", criteria: "last_played_date", asc: "Unwatched First", desc: "Watched First" },
            { tag: "main_artist", criteria: "main_artist", asc: "Artist A-Z", desc: "Artist Z-A" },
            { tag: "track_number", criteria: "track_number", asc: "Track Number Ascending", desc: "Track Number Descending" },
            { tag: "disc_number", criteria: "disc_number", asc: "Disc Number Ascending", desc: "Disc Number Descending" },
            { tag: "mrl", criteria: "mrl", asc: "URI Ascending", desc: "URI Descending" },
            { tag: "url", criteria: "url", asc: "URI Ascending", desc: "URI Descending" },
            { tag: "nb_tracks", criteria: "nb_tracks", asc: "Fewest Items First", desc: "Most Items First" },
            { tag: "nb_videos", criteria: "nb_videos", asc: "Fewest Items First", desc: "Most Items First" },
        ]
    }

    function test_sortRowLabel(data) {
        compare(Helpers.sortRowLabel(data.criteria, "ignored", Qt.AscendingOrder), data.asc)
        compare(Helpers.sortRowLabel(data.criteria, "ignored", Qt.DescendingOrder), data.desc)
    }

    function test_sidebarEntryState_data() {
        return [
            { tag: "home root", path: ["home"], uri: ["home"], state: 2 },
            { tag: "videos root", path: ["video"], uri: ["video"], state: 2 },
            { tag: "default subpage", path: ["video", "base"], uri: ["video"], state: 2 },
            { tag: "folder level", path: ["video", "folder"], uri: ["video"], state: 1 },
            { tag: "songs", path: ["music", "songs", "folder"], uri: ["music"], state: 1 },
            { tag: "other section", path: ["network"], uri: ["video"], state: 0 },
            { tag: "add item", path: ["home"], uri: ["additem"], state: 0 },
            { tag: "empty history", path: [], uri: ["home"], state: 0 },
        ]
    }

    function test_sidebarEntryState(data) {
        compare(Helpers.sidebarEntryState(data.path, data.uri), data.state)
    }

    function test_sameMedia_data() {
        return [
            { tag: "same", mrl: "file:///m/a.mp4", url: "file:///m/a.mp4", same: true },
            { tag: "space encoded", mrl: "file:///m/a%20b.mp4", url: "file:///m/a b.mp4", same: true },
            { tag: "non-ASCII", mrl: "file:///m/%C3%A9t%C3%A9.mp4", url: "file:///m/\u00e9t\u00e9.mp4", same: true },
            { tag: "different", mrl: "file:///m/a.mp4", url: "file:///m/b.mp4", same: false },
            { tag: "empty mrl", mrl: "", url: "file:///m/a.mp4", same: false },
            { tag: "empty url", mrl: "file:///m/a.mp4", url: "", same: false },
            { tag: "malformed %", mrl: "file:///m/a%E0%A4%A.mp4", url: "file:///m/a%E0%A4%A.mp4", same: true },
        ]
    }

    function test_sameMedia(data) {
        compare(Helpers.sameMedia(data.mrl, data.url), data.same)
    }

    function test_sortRowLabelFallback() {
        compare(Helpers.sortRowLabel("fileSizeRaw64", "File size", Qt.AscendingOrder), "File size Ascending")
        compare(Helpers.sortRowLabel("fileSizeRaw64", "File size", Qt.DescendingOrder), "File size Descending")
        compare(Helpers.sortRowLabel("", "", Qt.AscendingOrder), " Ascending")
    }

    readonly property var labels: ({ "video": "Videos", "video/playlists": "Playlists",
                                     "music": "Music", "music/albums": "Albums" })

    function test_breadcrumbs_titleOnLastLevel() {
        // Videos ▸ All ▸ base, titled "Videos": "all"/"base" have no label, the title repeats the last crumb
        compare(Helpers.breadcrumbs(["video", "all", "base"], "Videos", labels),
                [{ title: "Videos", path: ["video"] }])
    }

    function test_breadcrumbs_titleAppended() {
        compare(Helpers.breadcrumbs(["video", "playlists", "list"], "Road trip", labels),
                [{ title: "Videos", path: ["video"] },
                 { title: "Playlists", path: ["video", "playlists"] },
                 { title: "Road trip", path: ["video", "playlists", "list"] }])
    }

    function test_breadcrumbs_unknownPage() {
        compare(Helpers.breadcrumbs(["discover", "services"], "Services", labels),
                [{ title: "Services", path: ["discover", "services"] }])
    }

    function test_breadcrumbs_emptyTitle() {
        compare(Helpers.breadcrumbs(["music", "albums"], "", labels),
                [{ title: "Music", path: ["music"] }, { title: "Albums", path: ["music", "albums"] }])
        compare(Helpers.breadcrumbs([], "", labels), [])
    }

    function test_rankByFrequency() {
        compare(Helpers.rankByFrequency(["a", "b", "a", "", "c", "b", "a"]), ["a", "b", "c"])
    }

    function test_folderEntries() {
        compare(Helpers.folderEntries(["file:///m/Shows/e1.mkv", "file:///m/Films/f.mkv", "file:///m/Shows/e2.mkv"]),
                [{ mrl: "file:///m/Shows", name: "Shows" }, { mrl: "file:///m/Films", name: "Films" }])
    }

    function test_folderEntries_skipsNonFile() {
        compare(Helpers.folderEntries(["http://x/a.mp3", "dvd:///dev/sr0", "file:///m/My%20Music/t.mp3"]),
                [{ mrl: "file:///m/My%20Music", name: "My Music" }])
    }

    function test_folderEntries_skipsRootAndEmptyName() {
        compare(Helpers.folderEntries(["file:///t.mp3", "file:///m/Shows//x.mkv", "file:///m/A/x.mp3"]),
                [{ mrl: "file:///m/A", name: "A" }])
    }

    function test_folderEntries_malformedEscape() {
        compare(Helpers.folderEntries(["file:///m/Caf%E9/x.mp3"]),
                [{ mrl: "file:///m/Caf%E9", name: "Caf%E9" }])
    }

    // 6 items in 4 columns: [0 1 2 3] [4 5]
    function test_gridStep_data() {
        return [
            { tag: "up from 4", from: 4, dx: 0, dy: -1, to: 0 },
            { tag: "up from 5", from: 5, dx: 0, dy: -1, to: 1 },
            { tag: "up from the first row leaves", from: 1, dx: 0, dy: -1, to: -1 },
            { tag: "down from 1", from: 1, dx: 0, dy: 1, to: 5 },
            { tag: "down onto a short row", from: 2, dx: 0, dy: 1, to: 5 },
            { tag: "down from the last row leaves", from: 4, dx: 0, dy: 1, to: -1 },
            { tag: "right", from: 0, dx: 1, dy: 0, to: 1 },
            { tag: "right at a row end leaves", from: 3, dx: 1, dy: 0, to: -1 },
            { tag: "right at the last item leaves", from: 5, dx: 1, dy: 0, to: -1 },
            { tag: "left", from: 5, dx: -1, dy: 0, to: 4 },
            { tag: "left at a row start leaves", from: 4, dx: -1, dy: 0, to: -1 },
            { tag: "left at the first item leaves", from: 0, dx: -1, dy: 0, to: -1 },
        ]
    }

    function test_gridStep(data) {
        compare(Helpers.gridStep(data.from, data.dx, data.dy, 4, 6), data.to)
    }

    function test_gridStep_oneColumn() {
        compare(Helpers.gridStep(1, 0, -1, 1, 3), 0)
        compare(Helpers.gridStep(1, 0, 1, 1, 3), 2)
        compare(Helpers.gridStep(2, 0, 1, 1, 3), -1)
        compare(Helpers.gridStep(1, -1, 0, 1, 3), -1)
    }

    function test_rootItemCount() {
        compare(Helpers.rootItemCount([]), 0)
        compare(Helpers.rootItemCount([{ add: true }, { text: "a" }, { text: "b" }]), 2)
        compare(Helpers.rootItemCount([{ add: true }]), 0)
    }

    function test_withShares() {
        const fixed = [{ add: true, text: "Add" }, { text: "Podcasts" }]
        compare(Helpers.withShares(fixed, [], "g"), fixed)
        const r = Helpers.withShares(fixed, [{ name: "truenas" }, { name: "nas2" }], "g")
        compare(r.length, 4)
        compare(r[2].text, "truenas"); compare(r[2].share, 0); compare(r[2].glyph, "g")
        compare(r[3].share, 1)
        compare(fixed.length, 2) // input untouched
    }
}
