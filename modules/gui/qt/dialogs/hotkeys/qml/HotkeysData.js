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

// The shortcut dialog's sections. Every key-* option of src/libvlc-module.c appears exactly once
// (docs/superpowers/scripts/check-settings-options.py); a row without a label uses the option's own text.
const sections = [
    { title: qsTr("Basic"), rows: [
        { option: "key-toggle-fullscreen", label: qsTr("Toggle fullscreen") },
        { option: "key-leave-fullscreen", label: qsTr("Exit fullscreen / close dialog") },
        { option: "key-position", label: qsTr("Show playback position and time") },
        { option: "key-intf-show", label: qsTr("Show interface controls in fullscreen") },
        { option: "key-quit" },
        { option: "key-intf-boss" },
        { option: "key-intf-popup-menu" },
        { option: "key-snapshot" },
        { option: "key-record" },
        { option: "key-clear-playlist" }
    ] },
    { title: qsTr("Playback"), rows: [
        { option: "key-play-pause", label: qsTr("Play / pause") },
        { option: "key-stop", label: qsTr("Stop playback") },
        { option: "key-next", label: qsTr("Next track") },
        { option: "key-prev", label: qsTr("Previous track") },
        { option: "key-program-sid-next", label: qsTr("Next program / Service ID") },
        { option: "key-program-sid-prev" },
        { option: "key-pause" },
        { option: "key-play" },
        { option: "key-faster" },
        { option: "key-slower" },
        { option: "key-rate-normal" },
        { option: "key-rate-faster-fine" },
        { option: "key-rate-slower-fine" },
        { option: "key-frame-next" },
        { option: "key-frame-previous" },
        { option: "key-random" },
        { option: "key-loop" }
    ] },
    { title: qsTr("Seeking"), rows: [
        { option: "key-jump-extrashort" },
        { option: "key-jump+extrashort" },
        { option: "key-jump-short" },
        { option: "key-jump+short" },
        { option: "key-jump-medium" },
        { option: "key-jump+medium" },
        { option: "key-jump-long" },
        { option: "key-jump+long" },
        { option: "key-chapter-prev" },
        { option: "key-chapter-next" },
        { option: "key-title-prev" },
        { option: "key-title-next" },
        { option: "key-disc-menu" },
        { option: "key-nav-activate" },
        { option: "key-nav-up" },
        { option: "key-nav-down" },
        { option: "key-nav-left" },
        { option: "key-nav-right" }
    ] },
    { title: qsTr("Audio"), rows: [
        { option: "key-vol-up" },
        { option: "key-vol-down" },
        { option: "key-vol-mute" },
        { option: "key-audio-track" },
        { option: "key-audiodevice-cycle" },
        { option: "key-audiodelay-up" },
        { option: "key-audiodelay-down" }
    ] },
    { title: qsTr("Subtitles"), rows: [
        { option: "key-subtitle-revtrack" },
        { option: "key-subtitle-track" },
        { option: "key-subtitle-toggle" },
        { option: "key-subtitle-control-secondary" },
        { option: "key-subtitle-text-scale-normal" },
        { option: "key-subtitle-text-scale-up" },
        { option: "key-subtitle-text-scale-down" },
        { option: "key-subdelay-up" },
        { option: "key-subdelay-down" },
        { option: "key-subsync-markaudio" },
        { option: "key-subsync-marksub" },
        { option: "key-subsync-apply" },
        { option: "key-subsync-reset" },
        { option: "key-subpos-up" },
        { option: "key-subpos-down" }
    ] },
    { title: qsTr("Video"), rows: [
        { option: "key-aspect-ratio" },
        { option: "key-crop" },
        { option: "key-crop-top" },
        { option: "key-crop-left" },
        { option: "key-crop-bottom" },
        { option: "key-crop-right" },
        { option: "key-uncrop-top" },
        { option: "key-uncrop-left" },
        { option: "key-uncrop-bottom" },
        { option: "key-uncrop-right" },
        { option: "key-toggle-autoscale" },
        { option: "key-incr-scalefactor" },
        { option: "key-decr-scalefactor" },
        { option: "key-deinterlace" },
        { option: "key-deinterlace-mode" },
        { option: "key-zoom" },
        { option: "key-unzoom" },
        { option: "key-zoom-quarter" },
        { option: "key-zoom-half" },
        { option: "key-zoom-original" },
        { option: "key-zoom-double" },
        { option: "key-wallpaper" },
        { option: "key-projection-toggle" },
        { option: "key-viewpoint-fov-in" },
        { option: "key-viewpoint-fov-out" },
        { option: "key-viewpoint-roll-clock" },
        { option: "key-viewpoint-roll-anticlock" }
    ] },
    { title: qsTr("Bookmarks"), rows: [
        { option: "key-set-bookmark1" },
        { option: "key-set-bookmark2" },
        { option: "key-set-bookmark3" },
        { option: "key-set-bookmark4" },
        { option: "key-set-bookmark5" },
        { option: "key-set-bookmark6" },
        { option: "key-set-bookmark7" },
        { option: "key-set-bookmark8" },
        { option: "key-set-bookmark9" },
        { option: "key-set-bookmark10" },
        { option: "key-play-bookmark1" },
        { option: "key-play-bookmark2" },
        { option: "key-play-bookmark3" },
        { option: "key-play-bookmark4" },
        { option: "key-play-bookmark5" },
        { option: "key-play-bookmark6" },
        { option: "key-play-bookmark7" },
        { option: "key-play-bookmark8" },
        { option: "key-play-bookmark9" },
        { option: "key-play-bookmark10" }
    ] },
]

// Sections reduced to the rows that match text in field ("all", "action", "hotkey" or "global");
// labelOf(row) and keysOf(row, global) give the strings to search. Plain substring match, case-insensitive.
function filter(sections, labelOf, keysOf, text, field) {
    const t = text.trim().toLowerCase()
    if (t === "")
        return sections
    const has = s => String(s).toLowerCase().indexOf(t) !== -1
    const matches = row =>
        ((field === "all" || field === "action") && has(labelOf(row)))
        || ((field === "all" || field === "hotkey") && has(keysOf(row, false)))
        || ((field === "all" || field === "global") && has(keysOf(row, true)))
    return sections
        .map(s => ({ title: s.title, rows: s.rows.filter(matches) }))
        .filter(s => s.rows.length > 0)
}
