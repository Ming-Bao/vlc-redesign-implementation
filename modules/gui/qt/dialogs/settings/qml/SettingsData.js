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
//   placeholder  the text a field shows while empty
//   extra        a ',' separated list option whose entries are added to a dropdown's choices
//   editable     a dropdown whose text can also be typed
//   (a choice may carry `sets: {option: value}`: written with it, and part of what makes it the shown one)
//   choicesFrom  "languages" | "fonts" | "opticalDrives" | "screens" (dropdown)
//   min, max, step, ticks, scale, suffix
//                slider range in UI units, tick labels under it, config = UI x scale (e.g. 1000 for s -> ms),
//                text after a field's value (number, field)
//   invert       a toggle written inverted
//   on, off      the values a toggle writes (default true / false); "on" is also how it reads checked
//   list, module a toggle that adds or removes `module` in the ':' list option `list` (hides without `list`); on a
//                number row, `module` is in the list while the value is not 0 (Pitch shift)
//   save         browseFile picks a file to write (a save dialog)
//   action       button id: openConfig | resetAll | legacyPrefs | editHotkeys | resetHotkeys | clearHistory
//   buttonText   the button's text
//   component    a custom row: the file name (with .qml) of a file in dialogs/settings/qml/rows/, e.g. "ThemeRow.qml".
//                The VLC.Dialogs module serves its files flat (qrc:/qt/qml/VLC/Dialogs/<name>), so the delegate
//                loads it by that name. See SettingsRowDelegate for the component's properties. A name with no file
//                draws nothing and logs nothing.
//   keywords     extra search text, for custom rows
const MB = 1024 * 1024
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
    { name: "playback", label: qsTr("Playback"), title: qsTr("Playback Preferences"), icon: "playback", group: "Media", sections: [
        { title: qsTr("Startup"), rows: [
            { label: qsTr("Continue where you left off"), kind: "dropdown", option: "restore-playback-pos" },
            { label: qsTr("Start playing as soon as a file opens"), kind: "toggle", option: "playlist-autostart" },
            { label: qsTr("Default playback speed"), kind: "slider", option: "rate", min: 0.25, max: 2, step: 0.25,
              ticks: [ "0.25", "0.5", "0.75", "1", "1.25", "1.5", "1.75", "2" ] }
        ] },
        { title: qsTr("Tracks"), rows: [
            { label: qsTr("Preferred video quality"), kind: "dropdown", option: "preferred-resolution" },
            { label: qsTr("Preferred menu language"), kind: "dropdown", option: "menu-language", choicesFrom: "languages" },
            { label: qsTr("Default audio track"), kind: "number", option: "audio-track" },
            { label: qsTr("Default subtitle track"), kind: "number", option: "sub-track" }
        ] },
        { title: qsTr("Order"), rows: [
            { label: qsTr("Repeat"), kind: "custom", component: "RepeatRow.qml", option: "repeat", requires: "loop" },
            { label: qsTr("Shuffle"), kind: "toggle", option: "random" },
            { label: qsTr("Stop after each item"), kind: "toggle", option: "play-and-stop" },
            { label: qsTr("When playback finishes"), kind: "dropdown", option: "play-and-exit",
              choices: [ { value: false, label: qsTr("Stop") }, { value: true, label: qsTr("Quit") } ] }
        ] },
        { title: qsTr("Seeking"), rows: [
            { label: qsTr("Seek precisely"), kind: "toggle", option: "input-fast-seek", invert: true }
        ] },
        { title: qsTr("Discs and Files"), rows: [
            { label: qsTr("Default optical drive"), kind: "dropdown", option: "dvd", choicesFrom: "opticalDrives", editable: true },
            { label: qsTr("Repair damaged AVI files"), kind: "dropdown", option: "avi-index" },
            { label: qsTr("Load matching .mkv files from the same folder"), kind: "toggle", option: "mkv-preload-local-dir" }
        ] },
        { title: qsTr("Time-shift"), adv: true, rows: [
            { label: qsTr("Time-shift buffer folder"), kind: "browseFolder", adv: true, option: "input-timeshift-path" },
            { label: qsTr("Time-shift buffer size"), kind: "dropdown", adv: true, option: "input-timeshift-granularity",
              choices: [ { value: 10 * MB, label: qsTr("Small") }, { value: 50 * MB, label: qsTr("Medium") },
                         { value: 200 * MB, label: qsTr("Large") } ] }
        ] }
    ] },
    { name: "video", label: qsTr("Video"), title: qsTr("Video Defaults"), icon: "video", group: "Media", sections: [
        { title: qsTr("Output"), rows: [
            { label: qsTr("Enable video"), kind: "toggle", option: "video" },
            { label: qsTr("Start videos in fullscreen"), kind: "toggle", option: "fullscreen" },
            { label: qsTr("Stop the screensaver during playback"), kind: "toggle", option: "disable-screensaver" },
            { label: qsTr("Play video as desktop wallpaper"), kind: "toggle", option: "video-wallpaper" }
        ] },
        { title: qsTr("Picture"), rows: [
            { label: qsTr("Picture"), kind: "custom", component: "PictureRows.qml", option: "hue", requires: "gamma" }
        ] },
        { title: qsTr("Deinterlacing"), rows: [
            { label: qsTr("Deinterlacing"), kind: "dropdown", option: "deinterlace" },
            { label: qsTr("Method"), kind: "dropdown", option: "deinterlace-mode" }
        ] },
        { title: qsTr("Framing"), rows: [
            { label: qsTr("Aspect ratio"), kind: "dropdown", option: "aspect-ratio", extra: "custom-aspect-ratios",
              choices: [ { value: "", label: qsTr("Automatic") }, "16:9", "4:3", "1:1", "16:10", "2.21:1", "2.35:1", "2.39:1", "5:4" ]
                  .map((c) => typeof c === "string" ? { value: c, label: c } : c) },
            { label: qsTr("Crop"), kind: "dropdown", option: "crop", extra: "custom-crop-ratios",
              choices: [ { value: "", label: qsTr("None") }, "16:10", "16:9", "4:3", "185:100", "221:100", "235:100", "239:100", "5:3", "5:4", "1:1" ]
                  .map((c) => typeof c === "string" ? { value: c, label: c } : c) },
            { label: qsTr("Scale video to the window"), kind: "toggle", option: "autoscale" },
            { label: qsTr("Zoom"), kind: "dropdown", option: "zoom", requires: "autoscale",
              choices: [ { value: 1, label: qsTr("Fit"), sets: { autoscale: true } }, { value: 0.25, label: qsTr("\u00BC"), sets: { autoscale: false } },
                         { value: 0.5, label: qsTr("\u00BD"), sets: { autoscale: false } }, { value: 1, label: qsTr("1:1"), sets: { autoscale: false } },
                         { value: 2, label: qsTr("2:1"), sets: { autoscale: false } } ] },
            { label: qsTr("Position in the window"), kind: "dropdown", option: "align" }
        ] },
        { title: qsTr("Snapshots"), rows: [
            { label: qsTr("Save to"), kind: "browseFolder", option: "snapshot-path" },
            { label: qsTr("File name prefix"), kind: "field", option: "snapshot-prefix" },
            { label: qsTr("Format"), kind: "dropdown", option: "snapshot-format" },
            { label: qsTr("Size"), kind: "dropdown", option: "snapshot-width", requires: "snapshot-height",
              choices: [ { value: -1, label: qsTr("Same as video"), sets: { "snapshot-height": -1 } },
                         { value: 1920, label: qsTr("1920 wide"), sets: { "snapshot-height": -1 } },
                         { value: 1280, label: qsTr("1280 wide"), sets: { "snapshot-height": -1 } },
                         { value: 640, label: qsTr("640 wide"), sets: { "snapshot-height": -1 } } ] },
            { label: qsTr("Number files sequentially"), kind: "toggle", option: "snapshot-sequential" },
            { label: qsTr("Show a preview after capture"), kind: "toggle", option: "snapshot-preview" }
        ] },
        { title: "", adv: true, rows: [
            { label: qsTr("Custom aspect ratios"), kind: "field", adv: true, option: "custom-aspect-ratios" },
            { label: qsTr("Custom crop ratios"), kind: "field", adv: true, option: "custom-crop-ratios" },
            { label: qsTr("Monitor pixel aspect ratio"), kind: "field", adv: true, option: "monitor-par" }
        ] }
    ] },
    { name: "audio", label: qsTr("Audio"), title: qsTr("Audio Defaults"), icon: "audio", group: "Media", sections: [
        { title: qsTr("Output"), rows: [
            { label: qsTr("Enable audio"), kind: "toggle", option: "audio" },
            { label: qsTr("Output device"), kind: "dropdown", option: "aout" },
            { label: qsTr("Speaker setup"), kind: "dropdown", option: "stereo-mode" }
        ] },
        { title: qsTr("Volume"), rows: [
            { label: qsTr("Maximum volume"), kind: "slider", option: "qt-max-volume", min: 100, max: 300, step: 25,
              ticks: [ qsTr("100%"), qsTr("200%"), qsTr("300%") ] },
            { label: qsTr("Startup volume"), kind: "custom", component: "StartupVolumeRow.qml", option: "volume-save" },
            { label: qsTr("Volume step"), kind: "number", option: "volume-step" }
        ] },
        { title: qsTr("Loudness"), rows: [
            { label: qsTr("Normalize loudness"), kind: "toggle", list: "audio-filter", module: "normvol" },
            { label: qsTr("Target level"), kind: "number", option: "norm-max-level" },
            // "Night mode" is not built: no separate VLC filter (the Compressor below covers it)
            { label: qsTr("Replay gain"), kind: "dropdown", option: "audio-replay-gain-mode" },
            { label: qsTr("Replay gain preamp"), kind: "number", option: "audio-replay-gain-preamp" }
        ] },
        { title: qsTr("Effects"), rows: [
            { label: qsTr("Equalizer"), kind: "custom", component: "EqualizerRows.qml", list: "audio-filter", requires: "equalizer-bands",
              keywords: qsTr("Equalizer preset Preamp") },
            { label: qsTr("Two-pass"), kind: "toggle", option: "equalizer-2pass" },
            { label: qsTr("Spatial audio"), kind: "custom", component: "SpatialRows.qml", list: "audio-filter",
              keywords: qsTr("Spatial audio mode Headphone virtualization Room") },
            { label: qsTr("Stereo widening"), kind: "toggle", list: "audio-filter", module: "stereo_widen" },
            { label: qsTr("Compressor"), kind: "toggle", list: "audio-filter", module: "compressor" },
            // a pitch other than 0 also turns scaletempo_pitch on
            { label: qsTr("Pitch shift"), kind: "number", option: "pitch-shift", list: "audio-filter", module: "scaletempo_pitch" },
            { label: qsTr("Chorus/flanger"), kind: "toggle", list: "audio-filter", module: "chorus_flanger" },
            { label: qsTr("Karaoke"), kind: "toggle", list: "audio-filter", module: "karaoke" }
        ] },
        { title: qsTr("Language and Sync"), rows: [
            { label: qsTr("Preferred audio language"), kind: "dropdown", option: "audio-language", choicesFrom: "languages" },
            { label: qsTr("Audio delay"), kind: "number", option: "audio-desync", scale: 1000, suffix: qsTr(" s") },
            { label: qsTr("Visualizer"), kind: "dropdown", option: "audio-visual" }
        ] },
        { title: "", adv: true, rows: [
            { label: qsTr("Pass compressed audio to the receiver"), kind: "toggle", adv: true, option: "spdif" },
            { label: qsTr("Detect Dolby Surround"), kind: "dropdown", adv: true, option: "force-dolby-surround" },
            { label: qsTr("Resampling quality"), kind: "dropdown", adv: true, option: "audio-resampler" },
            { label: qsTr("Media role"), kind: "dropdown", adv: true, option: "role" },
            // Match window is not possible here: three sizes (my call)
            { label: qsTr("Visualization size"), kind: "dropdown", adv: true, option: "effect-width", requires: "effect-height",
              choices: [ { value: 400, label: qsTr("400 × 300"), sets: { "effect-height": 300 } },
                         { value: 800, label: qsTr("800 × 600"), sets: { "effect-height": 600 } },
                         { value: 1280, label: qsTr("1280 × 720"), sets: { "effect-height": 720 } } ] }
        ] }
    ] },
    { name: "subtitles", label: qsTr("Subtitles"), title: qsTr("Subtitle Defaults"), icon: "subtitles", group: "Media", sections: [
        { title: qsTr("Tracks & Languages"), rows: [
            { label: qsTr("Enable subtitles"), kind: "toggle", option: "spu" },
            { label: qsTr("Preferred language"), kind: "dropdown", option: "sub-language", choicesFrom: "languages" },
            { label: qsTr("Text encoding"), kind: "dropdown", option: "subsdec-encoding" }
        ] },
        { title: qsTr("Loading Subtitles"), rows: [
            { label: qsTr("Load subtitle files automatically"), kind: "toggle", option: "sub-autodetect-file" },
            { label: qsTr("File name matching"), kind: "dropdown", option: "sub-autodetect-fuzzy",
              choices: [ { value: 4, label: qsTr("Exact title") }, { value: 3, label: qsTr("Title with extra characters") },
                         { value: 2, label: qsTr("Title anywhere in the name") }, { value: 1, label: qsTr("Any subtitle file") } ] }
        ] },
        { title: qsTr("Appearance"), rows: [
            { label: qsTr("Font"), kind: "dropdown", option: "freetype-font", choicesFrom: "fonts" },
            // "Size values" is not built: VLC 4 has only a relative size (the freetype size options are obsolete)
            { label: qsTr("Font size"), kind: "dropdown", option: "sub-text-scale",
              choices: [ { value: 100, label: qsTr("Automatic") }, { value: 75, label: qsTr("Small") }, { value: 125, label: qsTr("Large") },
                         { value: 150, label: qsTr("Larger") }, { value: 200, label: qsTr("Largest") } ] },
            { label: qsTr("Bold"), kind: "toggle", option: "freetype-bold" },
            { label: qsTr("Text color"), kind: "color", option: "freetype-color" },
            { label: qsTr("Text opacity"), kind: "slider", option: "freetype-opacity", min: 0, max: 100, step: 10, scale: 2.55,
              ticks: [ qsTr("0%"), qsTr("50%"), qsTr("100%") ] },
            { label: qsTr("Outline thickness"), kind: "dropdown", option: "freetype-outline-thickness" },
            { label: qsTr("Outline color"), kind: "color", option: "freetype-outline-color" },
            { label: qsTr("Shadow"), kind: "toggle", option: "freetype-shadow-opacity", on: 128, off: 0 },
            { label: qsTr("Shadow color"), kind: "color", option: "freetype-shadow-color" },
            { label: qsTr("Shadow distance"), kind: "dropdown", option: "freetype-shadow-distance",
              choices: [ { value: 0.03, label: qsTr("Small") }, { value: 0.06, label: qsTr("Medium") }, { value: 0.1, label: qsTr("Large") } ] },
            { label: qsTr("Background"), kind: "dropdown", option: "freetype-background-opacity",
              choices: [ { value: 0, label: qsTr("None") }, { value: 128, label: qsTr("Box") } ] },
            { label: qsTr("Background color"), kind: "color", option: "freetype-background-color" },
            { label: qsTr("Background opacity"), kind: "slider", option: "freetype-background-opacity", min: 0, max: 100, step: 10, scale: 2.55,
              ticks: [ qsTr("0%"), qsTr("50%"), qsTr("100%") ] }
        ] },
        { title: qsTr("Position & Timing"), rows: [
            { label: qsTr("Vertical position"), kind: "dropdown", option: "sub-margin",
              choices: [ { value: 0, label: qsTr("Bottom") }, { value: 50, label: qsTr("Raised") }, { value: 150, label: qsTr("High") } ] },
            { label: qsTr("Subtitle delay"), kind: "slider", option: "sub-delay", min: -5, max: 5, step: 0.5, scale: 10,
              ticks: [ qsTr("-5 s"), qsTr("0 s"), qsTr("+5 s") ] }
        ] },
        { title: qsTr("On-screen Feedback"), rows: [
            { label: qsTr("Show feedback for shortcuts"), kind: "toggle", option: "osd" },
            // "Show feedback for" is not built: no VLC option
            { label: qsTr("Show filename when a video starts"), kind: "toggle", option: "video-title-show" },
            { label: qsTr("Show filename for"), kind: "slider", option: "video-title-timeout", min: 1, max: 10, step: 1, scale: 1000,
              ticks: [ qsTr("1 s"), qsTr("5 s"), qsTr("10 s") ], enabledBy: "video-title-show" }
        ] },
        // "Ignore styling in ASS and SSA subtitles" and the second "Visualization size" are not built: no VLC option / a Figma copy-paste
        { title: "", adv: true, rows: [
            { label: qsTr("Load subtitles from these folders"), kind: "field", adv: true, option: "sub-autodetect-path" },
            { label: qsTr("Shadow angle"), kind: "number", adv: true, option: "freetype-shadow-angle" },
            { label: qsTr("Text direction"), kind: "dropdown", adv: true, option: "freetype-text-direction" },
            { label: qsTr("Monospace font"), kind: "dropdown", adv: true, option: "freetype-monofont", choicesFrom: "fonts" }
        ] }
    ] },
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
    { name: "network", label: qsTr("Network"), title: qsTr("Network Connections & Security"), icon: "network", group: "System", sections: [
        { title: qsTr("Buffering"), rows: [
            { label: qsTr("Buffering"), kind: "custom", component: "BufferingRows.qml", option: "file-caching",
              requires: "live-caching" }
        ] },
        { title: qsTr("Proxy"), rows: [
            { label: qsTr("HTTP proxy"), kind: "field", option: "http-proxy", placeholder: qsTr("System proxy") },
            { label: qsTr("HTTP proxy password"), kind: "password", option: "http-proxy-pwd" }
        ] },
        { title: qsTr("Security"), rows: [
            { label: qsTr("Verify certificates against the system trust store"), kind: "toggle", option: "gnutls-system-trust" },
            { label: qsTr("Cipher preference"), kind: "dropdown", option: "gnutls-priorities" }
        ] }
    ] },
    { name: "performance", label: qsTr("Performance"), title: qsTr("Performance Settings"), icon: "performance", group: "System", sections: [
        { title: qsTr("Decoding"), rows: [
            { label: qsTr("Hardware-accelerated decoding"), kind: "dropdown", option: "dec-dev" },
            { label: qsTr("Video post-processing"), kind: "dropdown", option: "postproc-q",
              choices: [ { value: 0, label: qsTr("Off") }, 1, 2, 3, 4, 5, 6 ].map((c) => typeof c === "number" ? { value: c, label: String(c) } : c) },
            { label: qsTr("Skip the H.264 loop filter"), kind: "dropdown", option: "avcodec-skiploopfilter" },
            { label: qsTr("Decoding threads"), kind: "number", option: "avcodec-threads" }
        ] },
        { title: qsTr("Smooth Playback"), rows: [
            { label: qsTr("Drop frames when the system can't keep up"), kind: "toggle", option: "drop-late-frames" },
            { label: qsTr("Give VLC real-time priority"), kind: "toggle", option: "high-priority" }
        ] },
        { title: qsTr("Developer"), adv: true, rows: [
            { label: qsTr("Decoder"), kind: "dropdown", adv: true, option: "codec" },
            { label: qsTr("Clock synchronisation"), kind: "dropdown", adv: true, option: "clock-synchro" },
            { label: qsTr("Clock jitter"), kind: "number", adv: true, option: "clock-jitter", suffix: qsTr(" ms") }
        ] }
    ] },
    { name: "recording", label: qsTr("Recording"), title: qsTr("Recording, Casting & Streaming Out"), icon: "recording", group: "System", sections: [
        { title: qsTr("Recording"), rows: [
            { label: qsTr("Save recordings to"), kind: "browseFolder", option: "input-record-path" },
            { label: qsTr("Record without re-encoding when possible"), kind: "toggle", option: "input-record-native" }
        ] },
        { title: qsTr("Casting"), rows: [
            { label: qsTr("Cast quality"), kind: "dropdown", option: "sout-chromecast-conversion-quality" }
        ] },
        { title: qsTr("Streaming"), rows: [
            { label: qsTr("Play locally while streaming"), kind: "toggle", option: "sout-display" },
            { label: qsTr("Include audio"), kind: "toggle", option: "sout-audio" },
            { label: qsTr("Include video"), kind: "toggle", option: "sout-video" },
            { label: qsTr("Include subtitles"), kind: "toggle", option: "sout-spu" },
            { label: qsTr("Encoding preset"), kind: "dropdown", option: "sout-x264-preset" },
            { label: qsTr("Tuning"), kind: "dropdown", option: "sout-x264-tune" }
        ] }
    ] },
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

// Network's Buffering preset: "low" (half of each option's default), "normal" (the defaults), "high" (twice) when all
// four values match one, else "custom". `values` and `defaults` list the four caching options in the same order.
function presetFor(values, defaults) {
    const presets = [["normal", 1], ["low", 0.5], ["high", 2]]
    for (const [name, k] of presets)
        if (values.every((v, i) => Number(v) === Math.round(defaults[i] * k)))
            return name
    return "custom"
}
