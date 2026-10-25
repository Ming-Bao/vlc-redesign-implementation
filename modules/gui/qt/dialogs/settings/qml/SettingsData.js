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
// base name of pixmaps/redesign/settings/<icon>[-active].svg, and `sections` the page's rows (filled in by the pages).
// `group` is a key ("App" | "Media" | "System"); the sidebar translates it.
var pages = [
    { name: "general", label: qsTr("General"), title: qsTr("Global Settings"), icon: "general", group: "App", sections: [] },
    { name: "interface", label: qsTr("Interface"), title: qsTr("Interface Settings"), icon: "interface", group: "App", sections: [] },
    { name: "privacy", label: qsTr("Privacy"), title: qsTr("Privacy Settings"), icon: "privacy", group: "App", sections: [] },
    { name: "controls", label: qsTr("Controls"), title: qsTr("Mouse, Keyboard & Remote Controls"), icon: "controls", group: "App", sections: [] },
    { name: "playback", label: qsTr("Playback"), title: qsTr("Playback Preferences"), icon: "playback", group: "Media", sections: [] },
    { name: "video", label: qsTr("Video"), title: qsTr("Video Defaults"), icon: "video", group: "Media", sections: [] },
    { name: "audio", label: qsTr("Audio"), title: qsTr("Audio Defaults"), icon: "audio", group: "Media", sections: [] },
    { name: "subtitles", label: qsTr("Subtitles"), title: qsTr("Subtitle Defaults"), icon: "subtitles", group: "Media", sections: [] },
    { name: "library", label: qsTr("Library"), title: qsTr("Playlists, Folders & Files"), icon: "library", group: "Media", sections: [] },
    { name: "network", label: qsTr("Network"), title: qsTr("Network Connections & Security"), icon: "network", group: "System", sections: [] },
    { name: "performance", label: qsTr("Performance"), title: qsTr("Performance Settings"), icon: "performance", group: "System", sections: [] },
    { name: "recording", label: qsTr("Recording"), title: qsTr("Recording, Casting & Streaming Out"), icon: "recording", group: "System", sections: [] },
    { name: "extensions", label: qsTr("Extensions"), title: qsTr("Add-ons & Scripts"), icon: "extensions", group: "System", sections: [] }
]
