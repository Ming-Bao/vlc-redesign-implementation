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

import VLC.MainInterface

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// A library root (Music, Network): a grid of square tiles, or a compact list of rows.
// tiles: [{ glyph, text, add: bool, ... }]. The Add tile is not counted as an item.
Widgets.PageExt {
    id: root

    property var tiles: []

    signal tileActivated(var tile, int index, int reason)
    signal tileMenuRequested(var tile, int index, point globalPos)

    readonly property real _gap: VLCStyle.dp(20, VLCStyle.scale)
    readonly property int _columns: MainCtx.gridView
        ? Math.max(1, Math.floor((grid.width - grid.leftPadding - grid.rightPadding + _gap) / (VLCStyle.dp(200, VLCStyle.scale) + _gap)))
        : 1

    // the last tile that had focus (-1: none yet); `tiles` is reassigned live, so the delegates
    // are rebuilt and the focus is put back on this index, clamped to the new length
    property int _current: -1
    // and how it got it: a rebuilt tile keeps the keyboard's focus ring
    property int _reason: Qt.OtherFocusReason
    // clamped here too: a tile only updates _current when it gains focus, which the rebuilt
    // last tile does not while the grid is unfocused
    onTilesChanged: if (_current >= tiles.length) _current = tiles.length - 1
    readonly property int _target: {
        if (_current >= 0)
            return Math.min(_current, tiles.length - 1)
        const first = tiles.findIndex(t => !t.add)
        return first >= 0 ? first : 0
    }

    isSearchable: false
    // the header's grid / list toggle (the body is a Flow, not a MainViewLoader that would report it)
    hasGridListMode: true
    itemCount: Helpers.rootItemCount(tiles)

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // the cards eat the arrow keys: step through the tiles, or return false to fall
    // through to the body's Navigation (up: the header)
    function _move(from, dx, dy) {
        const to = Helpers.gridStep(from, dx, dy, _columns, repeater.count)
        if (to < 0)
            return false
        repeater.itemAt(to).forceActiveFocus(dx + dy > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        return true
    }

    // a plain assignment (not a binding); while the grid has the focus the tile takes it at once,
    // with the reason of the tile it replaces
    function _takeFocus(tile) {
        const reason = _reason
        tile.focus = true
        if (tile.activeFocus)
            tile.focusReason = reason
    }

    function setCurrentItemFocus(reason) {
        repeater.itemAt(_target)?.forceActiveFocus(reason)
    }

    FocusScope {
        id: body

        anchors.fill: parent
        focus: true

        Flow {
            id: grid

            anchors.fill: parent
            leftPadding: root.header?.leftPadding ?? 0
            rightPadding: root.header?.rightPadding ?? 0
            // Figma 970:4079: 20 under the header rule, which already has padding below it
            topPadding: Math.max(0, VLCStyle.dp(20, VLCStyle.scale) - (root.header?.bottomPadding ?? 0))
            flow: MainCtx.gridView ? Flow.LeftToRight : Flow.TopToBottom
            spacing: MainCtx.gridView ? root._gap : VLCStyle.dp(10, VLCStyle.scale)

            Repeater {
                id: repeater

                model: root.tiles

                delegate: MainCtx.gridView ? tileCard : tileRow
            }
        }
    }

    Component {
        id: tileCard

        HomeSquareCard {
            required property var modelData
            required property int index

            glyph: modelData.glyph
            backing: theme.palette?.isDark ? "#1E1E1E" : theme.bg.secondary
            title: modelData.text

            Navigation.parentItem: body
            Navigation.leftAction: () => root._move(index, -1, 0)
            Navigation.rightAction: () => root._move(index, 1, 0)
            Navigation.upAction: () => root._move(index, 0, -1)
            Navigation.downAction: () => root._move(index, 0, 1)

            // only the delegates' creation picks the target
            Component.onCompleted: if (index === root._target) root._takeFocus(this)
            onActiveFocusChanged: if (activeFocus) { root._current = index; root._reason = focusReason }

            onActivated: (reason) => root.tileActivated(modelData, index, reason)
            onMenuRequested: (globalPos) => root.tileMenuRequested(modelData, index, globalPos)
        }
    }

    Component {
        id: tileRow

        HomeListRow {
            required property var modelData
            required property int index

            // ponytail: list rows take the Videos/Music list's 400 base, not the full width
            width: VLCStyle.dp(400, VLCStyle.scale)
            compact: true
            glyph: modelData.glyph
            text: modelData.text

            Navigation.parentItem: body
            Navigation.leftAction: () => root._move(index, -1, 0)
            Navigation.rightAction: () => root._move(index, 1, 0)
            Navigation.upAction: () => root._move(index, 0, -1)
            Navigation.downAction: () => root._move(index, 0, 1)

            Component.onCompleted: if (index === root._target) root._takeFocus(this)
            onActiveFocusChanged: if (activeFocus) { root._current = index; root._reason = focusReason }

            onActivated: (reason) => root.tileActivated(modelData, index, reason)
            onMenuRequested: (globalPos) => root.tileMenuRequested(modelData, index, globalPos)
        }
    }
}
