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

// Page 3 of the onboarding card. A key is a key-* option name, or a literal written "=Ctrl+L".
const rows = [
    { label: qsTr("Play / Pause"), keys: ["key-play-pause"] },
    { label: qsTr("Seek Backward / Forward"), keys: ["key-jump-extrashort", "key-jump+extrashort"] },
    { label: qsTr("Previous / Next Item"), keys: ["key-prev", "key-next"] },
    { label: qsTr("Previous / Next Frame"), keys: ["key-frame-previous", "key-frame-next"] },
    { label: qsTr("Cycle Subtitle Track"), keys: ["key-subtitle-track"] },
    { label: qsTr("Cycle Audio Track"), keys: ["key-audio-track"] },
    { label: qsTr("Toggle Fullscreen"), keys: ["key-toggle-fullscreen"] },
    { label: qsTr("Increase / Decrease Volume"), keys: ["key-vol-up", "key-vol-down"] },
    { label: qsTr("Show / Hide Queue"), keys: ["=Ctrl+L"] },
    { label: qsTr("Show / Hide File Browser"), keys: ["=Ctrl+Shift+L"] },
    { label: qsTr("Take a Snapshot"), keys: ["key-snapshot"] },
    { label: qsTr("Record"), keys: ["key-record"] },
]

const _special = { Left: "←", Right: "→", Up: "↑", Down: "↓", Esc: "esc" }
const _modifiers = ["Shift", "Ctrl", "Alt", "Meta", "Command"]

// One binding ("Shift+s", maybe "n\tMedia Next Track") as the caps to draw.
function caps(value) {
    const first = String(value === undefined || value === null ? "" : value).split("\t")[0].trim()
    if (first === "")
        return ["—"]
    return first.split("+").map(p => _special[p] || (_modifiers.includes(p) || p.length === 1 ? p.toUpperCase() : p))
}
