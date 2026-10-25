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
    // the accent comes from the theme (qt-accent-color); dark: the background is it at 26 % over black (#371F06 for
    // #D37918), the dim one is it darkened (~#AB6314)
    // the accent is only defined in the View set (any window part may be built on another set)
    readonly property ColorContext _view: ColorContext { palette: style.theme.palette; colorSet: ColorContext.View }
    readonly property color accent:    _view.accent
    readonly property color accentBg:  dark ? Qt.rgba(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 1) : Qt.alpha(accent, 0.25)
    readonly property color accentDim: dark ? Qt.darker(accent, 1.24) : accent
    readonly property color knobOff:   dark ? "#404040" : theme.fg.secondary
    readonly property color divider:   dark ? "#222222" : theme.separator
    readonly property color box:       dark ? "#1B1B1B" : theme.bg.secondary
    // controls dim to this when !enabled (e.g. vout-backed controls without a video output)
    readonly property real disabledOpacity: 0.4
    readonly property color tick:      dark ? "#2A2A2A" : theme.separator

    // the settings window's own frame (Figma "Settings - *"): card, top bar, search box and sidebar
    readonly property color windowBg:        dark ? Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.95) : theme.bg.primary
    readonly property color topBar:          dark ? "#090909" : theme.bg.secondary
    readonly property color searchBg:        dark ? "#151515" : theme.bg.primary
    readonly property color placeholder:     dark ? "#404040" : theme.fg.secondary
    readonly property color sidebarBg:       dark ? Qt.rgba(25 / 255, 25 / 255, 25 / 255, 0.95) : theme.bg.secondary
    readonly property color sidebarSelected: dark ? "#222222" : theme.bg.primary
    readonly property color sidebarHover:    dark ? "#1E1E1E" : theme.bg.primary
    readonly property color labelActive:     dark ? "#EAEAEA" : theme.fg.primary
    // the settings window's pages: section headers, row labels, the Advanced Options bar
    readonly property color sectionTitle:    dark ? "#C6C6C6" : theme.fg.primary
    readonly property color rowLabel:        dark ? "#8F8F8F" : theme.fg.primary
    readonly property color advancedBg:      dark ? Qt.rgba(25 / 255, 25 / 255, 25 / 255, 0.95) : theme.bg.secondary
}
