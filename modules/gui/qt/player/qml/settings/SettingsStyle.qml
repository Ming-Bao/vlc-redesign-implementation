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
import VLC.Style

// the settings tabs read the Figma tokens (theme.palette.tokens): Dark/* in dark, the Light/* partner in light
QtObject {
    id: style
    required property ColorContext theme
    readonly property var _t: theme.palette.tokens

    readonly property color label:     _t.fgA3
    readonly property color value:     _t.fgA2
    readonly property color title:     _t.fgA1
    readonly property color field:     _t.bgB2
    readonly property color face:      _t.bgA4
    // the accent comes from the theme (qt-accent-color); the tokens derive the background and dim ones from it
    // the accent is only defined in the View set (any window part may be built on another set)
    readonly property ColorContext _view: ColorContext { palette: style.theme.palette; colorSet: ColorContext.View }
    readonly property color accent:    _view.accent
    // the accent as text or an icon (light: Accent/Dim, so it reads on light grey); `accent` stays for fills and rings
    readonly property color accentText: _view.accentText
    readonly property color accentBg:  _t.accentBgBright
    readonly property color accentDim: _t.accentDim
    readonly property color knobOff:   _t.fgA4
    readonly property color divider:   _t.dividerDim
    readonly property color box:       _t.bgA3
    // controls dim to this when !enabled (e.g. vout-backed controls without a video output)
    readonly property real disabledOpacity: 0.4
    readonly property color tick:      theme.palette.isDark ? "#2A2A2A" : _t.bgA1   // fixed colour: off-token dark value

    // the settings window's own frame (Figma "Settings - *"): card, top bar, search box and sidebar
    // light reads the opaque partner: these are separate windows (and the Customize Player card over the player), and
    // 20-25 % of the desktop or video under them made light text unreadable (slice 10 Ledger); dark keeps the frame's
    readonly property color windowBg:        theme.palette.isDark ? _t.bgB1Transparent : _t.bgB1
    readonly property color topBar:          _t.bgB2
    readonly property color searchBg:        _t.bgA5
    readonly property color placeholder:     _t.fgA4
    readonly property color sidebarBg:       theme.palette.isDark ? _t.bgA3Transparent : _t.bgA3
    readonly property color sidebarSelected: _t.bgA1
    readonly property color sidebarHover:    theme.palette.isDark ? "#1E1E1E" : _t.bgA2   // fixed colour: off-token dark value
    readonly property color labelActive:     _t.fg1
    // the settings window's pages: section headers, row labels, the Advanced Options bar
    readonly property color sectionTitle:    _t.fg2
    readonly property color rowLabel:        _t.fgA2
    readonly property color chipBg:          _t.bgA2   // the "applies" chip after a row label
    readonly property color advancedBg:      _t.bgA3Transparent
}
