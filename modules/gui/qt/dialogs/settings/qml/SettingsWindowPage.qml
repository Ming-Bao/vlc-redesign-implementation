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
import QtQuick.Templates as T

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

import "SettingsData.js" as SettingsData

// One settings page from SettingsData.js (not SettingsPage: VLC.Player has one, and PlaybackPanel imports both modules): its sections, then the Advanced Options bar and the Advanced rows (the
// page's `adv` rows as one untitled block, then its `adv` sections). The instance lives for the session and follows
// `page`; the bar's state is kept per page.
Flickable {
    id: root

    required property var page
    // SettingsData.search() output while searching, else null: the matches replace the page, grouped by page title
    property var results: null
    property bool advancedOpen: false

    property int _tick: 0
    property var _openByPage: ({})

    // [{title, rows}] for the main part and for the Advanced part. A row is Advanced iff `row.adv`; an `adv` section
    // is a block under the bar.
    readonly property var _main: results ? results : page.sections.filter((s) => !s.adv)
        .map((s) => ({ title: s.title, rows: s.rows.filter((r) => !r.adv) }))
    readonly property var _adv: results ? [] : [{ title: "", rows: [].concat(...page.sections.filter((s) => !s.adv)
                                                             .map((s) => s.rows.filter((r) => r.adv))) }]
        .concat(page.sections.filter((s) => s.adv).map((s) => ({ title: s.title, rows: s.rows.filter((r) => r.adv) })))
    readonly property bool _hasAdv: _adv.some(_anyShown)

    // from the data, not the delegates: right on every page, whatever was instantiated
    function _anyShown(block) { return block.rows.some((r) => SettingsData.rowShown(r, SettingsBridge)) }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    // re-read every row (values may have changed outside the bridge while the page was hidden)
    function reload() { _tick++ }

    onPageChanged: {
        advancedOpen = !!_openByPage[page.name]
        contentY = 0
        reload()
    }
    onResultsChanged: contentY = 0
    onAdvancedOpenChanged: _openByPage[page.name] = advancedOpen

    clip: true
    contentWidth: width
    contentHeight: column.y + column.height + VLCStyle.dp(100, VLCStyle.scale)
    boundsBehavior: Flickable.StopAtBounds
    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    // a titled (or untitled) block of rows; hidden, header included, when none of its rows is shown
    component Block: Column {
        id: block

        required property var modelData
        width: column.width
        visible: root._anyShown(modelData)

        Widgets.LabelExt {
            visible: text.length > 0
            topPadding: VLCStyle.dp(10, VLCStyle.scale)
            bottomPadding: VLCStyle.dp(10, VLCStyle.scale)
            text: block.modelData.title
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            font.weight: Font.Medium
            color: root._s.sectionTitle
            Accessible.role: Accessible.Heading
        }

        Repeater {
            id: rows
            model: block.modelData.rows
            SettingsRowDelegate {
                required property var modelData
                row: modelData
                reloadTick: root._tick
            }
        }
    }

    Column {
        id: column

        x: VLCStyle.dp(24, VLCStyle.scale)
        y: VLCStyle.dp(20, VLCStyle.scale)
        width: root.width - 2 * x
        spacing: VLCStyle.dp(20, VLCStyle.scale)

        Repeater {
            model: root._main
            Block { }
        }

        Widgets.LabelExt {
            visible: root.results && !root._main.some(root._anyShown)
            text: qsTr("No results")
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            color: root._s.placeholder
            Accessible.role: Accessible.StaticText
        }

        AdvancedBar {
            id: bar

            width: parent.width
            visible: root._hasAdv
            open: root.advancedOpen
            onClicked: root.advancedOpen = !root.advancedOpen
        }

        Column {
            width: parent.width
            visible: bar.visible && root.advancedOpen
            spacing: VLCStyle.dp(20, VLCStyle.scale)

            Repeater {
                model: root._adv
                Block { }
            }
        }
    }
}
