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
}
