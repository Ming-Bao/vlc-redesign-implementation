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

// Figma dark tokens for the settings tabs (Dark/FG/A1…A4, Dark/BG/*); light mode falls back to the theme
QtObject {
    id: style
    required property ColorContext theme
    readonly property bool dark: theme.palette.isDark

    readonly property color label:     dark ? "#6B6B6B" : theme.fg.secondary
    readonly property color value:     dark ? "#8F8F8F" : theme.fg.primary
    readonly property color title:     dark ? "#969696" : theme.fg.primary
    readonly property color field:     dark ? "#090909" : theme.bg.secondary
    readonly property color face:      dark ? "#191919" : theme.bg.primary
    readonly property color accentBg:  dark ? "#371F06" : Qt.alpha(theme.accent, 0.25)
    readonly property color accent:    dark ? "#D37918" : theme.accent
    readonly property color accentDim: dark ? "#AB6314" : theme.accent
    readonly property color knobOff:   dark ? "#404040" : theme.fg.secondary
    readonly property color divider:   dark ? "#222222" : theme.separator
    readonly property color box:       dark ? "#1B1B1B" : theme.bg.secondary
    // controls dim to this when !enabled (e.g. vout-backed controls without a video output)
    readonly property real disabledOpacity: 0.4
    readonly property color tick:      dark ? "#2A2A2A" : theme.separator
}
