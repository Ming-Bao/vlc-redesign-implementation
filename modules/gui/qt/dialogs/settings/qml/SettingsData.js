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
.pragma library

// The settings window's pages, in sidebar order. `label` is the sidebar text, `title` the title-bar text, `icon` the
// base name of pixmaps/redesign/settings/<icon>[-active].svg, `group` a key ("App" | "Media" | "System") that the
// sidebar translates.
//
// `sections`: [{ title, adv, rows }]. Rows carry the Advanced flag: a row is Advanced iff it has `adv: true`
// (search and the Advanced split read only that). A section's `adv: true` only places it under the Advanced Options
// bar, as a block (with its title, if any) after the Advanced rows of the page's other sections; every row in such
// a section must still say `adv: true`.
//
// A row (SettingsRowDelegate draws it):
//   label        the row text
//   kind         toggle | dropdown | field | password | number | browseFile | browseFolder | button | wideButton |
//                slider | segments | color | custom
//   option       the VLC option it reads and writes; the row hides when the build doesn't have it
//   adv          the row sits under the Advanced Options bar
//   requires     another option the row needs, to hide it with a plugin that isn't built (e.g. skins2)
//   enabledBy    a bool option that must be on for the row to be enabled (it dims otherwise)
//   choices      [{value, label}], the row's own list (dropdown, segments, or the stops of a slider), overriding VLC's
//   choicesFrom  "languages" | "fonts" | "opticalDrives" | "screens" (dropdown)
//   min, max, step, ticks, scale, suffix
//                slider range in UI units, tick labels under it, config = UI x scale (e.g. 1000 for s -> ms),
//                text after a field's value (number, field)
//   invert       a toggle written inverted
//   on, off      the values a toggle writes (default true / false); "on" is also how it reads checked
//   list, module a toggle that adds or removes `module` in the ':' list option `list` (hides without `list`)
//   save         browseFile picks a file to write (a save dialog)
//   action       button id: openConfig | resetAll | legacyPrefs | editHotkeys | resetHotkeys | clearHistory
//   buttonText   the button's text
//   component    a custom row: the file name (with .qml) of a file in dialogs/settings/qml/rows/, e.g. "ThemeRow.qml".
//                The VLC.Dialogs module serves its files flat (qrc:/qt/qml/VLC/Dialogs/<name>), so the delegate
//                loads it by that name. See SettingsRowDelegate for the component's properties. A name with no file
//                draws nothing and logs nothing.
//   keywords     extra search text, for custom rows
var pages = [
    { name: "general", label: qsTr("General"), title: qsTr("Global Settings"), icon: "general", group: "App", sections: [
        { title: qsTr("Appearance"), rows: [
            { label: qsTr("Theme"), kind: "custom", component: "ThemeRow.qml", keywords: qsTr("Dark Light System") },
            { label: qsTr("Accent color"), kind: "custom", component: "AccentRow.qml" }
        ] },
        { title: qsTr("Startup"), rows: [
            { label: qsTr("Show confirmation and error dialogs"), kind: "toggle", option: "qt-error-dialogs" },
            { label: qsTr("Check for updates automatically"), kind: "toggle", option: "qt-updates-notif" }
        ] },
        { title: qsTr("Diagnostics"), rows: [
            { label: qsTr("Save a log"), kind: "toggle", option: "file-logging" },
            { label: qsTr("Log file"), kind: "browseFile", option: "logfile", save: true },
            { label: qsTr("Log details"), kind: "dropdown", option: "log-verbose" },
            { label: qsTr("Log format"), kind: "dropdown", option: "logmode", adv: true },
            { label: qsTr("Collect playback statistics"), kind: "toggle", option: "stats", adv: true },
            { label: qsTr("Open configurations folder"), kind: "button", action: "openConfig", buttonText: qsTr("Open"), adv: true },
            { label: qsTr("Reset all settings"), kind: "button", action: "resetAll", buttonText: qsTr("Reset"), adv: true },
            { label: qsTr("All settings"), kind: "button", action: "legacyPrefs", buttonText: qsTr("Open"), adv: true }
        ] },
        { title: qsTr("Developer Options"), adv: true, rows: [
            { label: qsTr("Write to the system log"), kind: "toggle", adv: true, option: "syslog" },
            { label: qsTr("Include debug messages in the system log"), kind: "toggle", adv: true, option: "syslog-debug" },
            { label: qsTr("System log identity"), kind: "field", adv: true, option: "syslog-ident" },
            { label: qsTr("System log facility"), kind: "dropdown", adv: true, option: "syslog-facility" }
        ] }
    ] },
    { name: "interface", label: qsTr("Interface"), title: qsTr("Interface Settings"), icon: "interface", group: "App", sections: [
        { title: qsTr("Skin"), rows: [
            { label: qsTr("Use a custom skin"), kind: "toggle", option: "intf", on: "skins2", off: "qt", requires: "skins2-last" },
            { label: qsTr("Skin file"), kind: "browseFile", option: "skins2-last" }
        ] },
        { title: qsTr("Window"), rows: [
            { label: qsTr("Play video inside main window"), kind: "toggle", option: "embedded-video" },
            { label: qsTr("Resize window to fit video"), kind: "dropdown", option: "qt-video-autoresize",
              choices: [ { value: false, label: qsTr("Never") }, { value: true, label: qsTr("Always") } ] },
            { label: qsTr("Keep window above other windows"), kind: "toggle", option: "video-on-top" },
            { label: qsTr("Show window decorations"), kind: "toggle", option: "video-deco" },
            { label: qsTr("Show the file name in the title bar"), kind: "toggle", option: "qt-name-in-title" },
            { label: qsTr("Open fullscreen on"), kind: "dropdown", option: "qt-fullscreen-screennumber", choicesFrom: "screens" }
        ] },
        { title: qsTr("Playback Controls"), rows: [
            { label: qsTr("Start in compact mode"), kind: "toggle", option: "qt-minimal-view" },
            { label: qsTr("Hide after"), kind: "slider", option: "mouse-hide-timeout", min: 0, max: 10, step: 0.5, scale: 1000,
              ticks: [ qsTr("0 s"), qsTr("5 s"), qsTr("10 s") ] },
            { label: qsTr("Show controls in fullscreen"), kind: "toggle", option: "qt-fs-controller" }
        ] },
        { title: qsTr("Notifications and System Tray"), rows: [
            { label: qsTr("Show a system tray icon"), kind: "toggle", option: "qt-system-tray" },
            { label: qsTr("Start minimized to the tray"), kind: "toggle", option: "qt-start-minimized" },
            { label: qsTr("Show a popup when the track changes"), kind: "dropdown", option: "qt-notification" }
        ] },
        { title: qsTr("Playlist"), rows: [
            { label: qsTr("Show the playlist as a tree"), kind: "toggle", option: "playlist-tree" }
        ] },
        { title: "", adv: true, rows: [
            { label: qsTr("Window opacity"), kind: "slider", adv: true, option: "qt-opacity", min: 10, max: 100, step: 10, scale: 0.01,
              ticks: [ qsTr("10%"), qsTr("100%") ] },
            { label: qsTr("Pause video when window is minimized"), kind: "toggle", adv: true, option: "qt-pause-minimized" },
            { label: qsTr("Bring VLC to the front when playback starts"), kind: "dropdown", adv: true, option: "qt-auto-raise" },
            { label: qsTr("Show cover art in the window when playing audio"), kind: "toggle", adv: true, option: "qt-bgcone" },
            { label: qsTr("Show the file browser inside the open dialog"), kind: "toggle", adv: true, option: "qt-embedded-open" },
            { label: qsTr("Allow the app icon to change"), kind: "toggle", adv: true, option: "qt-icon-change" },
            { label: qsTr("Fullscreen controls opacity"), kind: "slider", adv: true, option: "qt-fs-opacity", min: 10, max: 100, step: 10, scale: 0.01,
              ticks: [ qsTr("10%"), qsTr("100%") ] },
            // three stops in px from the bottom edge (my call)
            { label: qsTr("Fullscreen controls sensitivity"), kind: "slider", adv: true, option: "qt-fs-sensitivity",
              choices: [ { value: 30, label: qsTr("Low") }, { value: 90, label: qsTr("Medium") }, { value: 300, label: qsTr("High") } ] }
        ] }
    ] },
    { name: "privacy", label: qsTr("Privacy"), title: qsTr("Privacy Settings"), icon: "privacy", group: "App", sections: [
        { title: qsTr("History"), rows: [
            { label: qsTr("Save recently played items"), kind: "toggle", option: "save-recentplay" },
            { label: qsTr("Remember the playback position"), kind: "toggle", option: "restore-playback-states" },
            // "Never remember items matching" (qt-recentplay-filter) is not built: VLC 4 made the option obsolete
            { label: qsTr("Clear history now"), kind: "button", action: "clearHistory", buttonText: qsTr("Clear") }
        ] },
        { title: qsTr("Network"), rows: [
            { label: qsTr("Fetch titles and cover art from the internet"), kind: "toggle", option: "metadata-network-access" },
            { label: qsTr("Submit played tracks to last.fm"), kind: "toggle", list: "extraintf", module: "audioscrobbler",
              requires: "lastfm-username" },
            { label: qsTr("Last.fm username"), kind: "field", option: "lastfm-username" },
            { label: qsTr("Last.fm password"), kind: "password", option: "lastfm-password" },
            { label: qsTr("Last.fm submission URL"), kind: "field", option: "scrobbler-url" }
        ] }
    ] },
    { name: "controls", label: qsTr("Controls"), title: qsTr("Mouse, Keyboard & Remote Controls"), icon: "controls", group: "App", sections: [
        { title: qsTr("Keyboard Shortcuts"), rows: [
            { label: qsTr("Defaults"), kind: "wideButton", action: "editHotkeys", buttonText: qsTr("Edit Keyboard Shortcuts") },
            { label: qsTr("Reset all shortcuts"), kind: "wideButton", action: "resetHotkeys", buttonText: qsTr("Reset") }
        ] },
        { title: qsTr("Skip Amounts"), rows: [
            { label: qsTr("Very short skip"), kind: "number", option: "extrashort-jump-size", suffix: " s" },
            { label: qsTr("Short skip"), kind: "number", option: "short-jump-size", suffix: " s" },
            { label: qsTr("Medium skip"), kind: "number", option: "medium-jump-size", suffix: " s" },
            { label: qsTr("Long skip"), kind: "number", option: "long-jump-size", suffix: " s" }
        ] },
        { title: qsTr("Mouse"), rows: [
            { label: qsTr("Scroll wheel"), kind: "dropdown", option: "hotkeys-y-wheel-mode" },
            { label: qsTr("Horizontal scroll"), kind: "dropdown", option: "hotkeys-x-wheel-mode" }
        ] },
        { title: qsTr("Remotes"), rows: [
            { label: qsTr("Web remote control"), kind: "toggle", list: "extraintf", module: "http", requires: "http-password" },
            { label: qsTr("Port"), kind: "number", option: "http-port" },
            { label: qsTr("Password"), kind: "password", option: "http-password" }
        ] }
    ] },
    { name: "playback", label: qsTr("Playback"), title: qsTr("Playback Preferences"), icon: "playback", group: "Media", sections: [] },
    { name: "video", label: qsTr("Video"), title: qsTr("Video Defaults"), icon: "video", group: "Media", sections: [] },
    { name: "audio", label: qsTr("Audio"), title: qsTr("Audio Defaults"), icon: "audio", group: "Media", sections: [] },
    { name: "subtitles", label: qsTr("Subtitles"), title: qsTr("Subtitle Defaults"), icon: "subtitles", group: "Media", sections: [] },
    { name: "library", label: qsTr("Library"), title: qsTr("Playlists, Folders & Files"), icon: "library", group: "Media", sections: [
        { title: qsTr("Opening Files"), rows: [
            { label: qsTr("Only allow one VLC window"), kind: "toggle", option: "one-instance" },
            { label: qsTr("Apply to files opened from the file manager"), kind: "toggle", option: "one-instance-when-started-from-file",
              enabledBy: "one-instance" },
            { label: qsTr("Add to the playlist instead of replacing it"), kind: "toggle", option: "playlist-enqueue", enabledBy: "one-instance" },
            { label: qsTr("When opening a folder"), kind: "dropdown", option: "recursive" },
            { label: qsTr("Show hidden files"), kind: "toggle", option: "show-hiddenfiles" }
        ] },
        { title: qsTr("Metadata & Artwork"), rows: [
            { label: qsTr("Fetch titles and artwork"), kind: "dropdown", option: "metadata-network-access",
              choices: [ { value: false, label: qsTr("From the file only") }, { value: true, label: qsTr("Also from the internet") } ] },
            { label: qsTr("Use the media library"), kind: "toggle", option: "media-library" }
        ] }
    ] },
    { name: "network", label: qsTr("Network"), title: qsTr("Network Connections & Security"), icon: "network", group: "System", sections: [] },
    { name: "performance", label: qsTr("Performance"), title: qsTr("Performance Settings"), icon: "performance", group: "System", sections: [] },
    { name: "recording", label: qsTr("Recording"), title: qsTr("Recording, Casting & Streaming Out"), icon: "recording", group: "System", sections: [] },
    { name: "extensions", label: qsTr("Extensions"), title: qsTr("Add-ons & Scripts"), icon: "extensions", group: "System", sections: [] }
]

// Whether a row can show in this build: its option, list and required option all exist. `bridge` is the
// SettingsBridge singleton (a .pragma library can't see it). A custom row also needs its component file, which
// only the delegate can tell (its `shown`).
function rowShown(row, bridge) {
    return (!row.option || bridge.exists(row.option))
        && (!row.list || bridge.exists(row.list))
        && (!row.requires || bridge.exists(row.requires))
}
