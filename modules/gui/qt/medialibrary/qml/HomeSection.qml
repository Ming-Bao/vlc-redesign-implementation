/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// A Home row (Figma 6261:15142): "Title ›" over one line of cards, or over compact rows in list view (1106:5633)
FocusScope {
    id: root

    property string title
    // an ML model (whose `limit` the page binds to `fit`) or a JS array
    property var model
    property Component cardDelegate
    property Component listDelegate
    property real cardWidth
    // centre x (card row coordinates, the same in every section) of the card focused
    // last on the page, so that moving between rows keeps the column
    property real focusX: 0

    readonly property real _gap: VLCStyle.dp(20, VLCStyle.scale)

    // number of cards that fit the width on one line, or the number of list rows
    readonly property int fit: MainCtx.gridView ? Math.max(1, Math.floor((width + _gap) / (cardWidth + _gap))) : 5
    readonly property int count: MainCtx.gridView ? cards.count : rows.count

    signal titleClicked(int reason)
    signal cardFocused(real x)

    // focus the card nearest `focusX`, or the first row (the last one coming from below)
    function setCurrentItemFocus(reason) {
        if (!MainCtx.gridView) {
            rows.itemAt(reason === Qt.BacktabFocusReason ? rows.count - 1 : 0)?.forceActiveFocus(reason)
            return
        }
        let best = null
        let bestDistance = Infinity
        for (let i = 0; i < cards.count; ++i) {
            const card = cards.itemAt(i)
            const distance = Math.abs(card.x + card.width / 2 - focusX)
            if (distance < bestDistance) {
                best = card
                bestDistance = distance
            }
        }
        if (best)
            best.forceActiveFocus(reason)
    }

    visible: count > 0

    implicitHeight: column.implicitHeight

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property color _titleColor: theme.palette?.isDark ? "#969696" : theme.fg.primary

    Column {
        id: column

        width: parent.width
        topPadding: MainCtx.gridView ? root._gap : VLCStyle.dp(14, VLCStyle.scale)
        bottomPadding: MainCtx.gridView ? root._gap : VLCStyle.dp(15, VLCStyle.scale)
        spacing: MainCtx.gridView ? 0 : VLCStyle.dp(14, VLCStyle.scale)

        T.AbstractButton {
            id: titleButton

            focusPolicy: Qt.StrongFocus
            text: root.title

            // list view pushes the chevron to the far right
            implicitWidth: MainCtx.gridView ? implicitContentWidth : column.width
            implicitHeight: implicitContentHeight

            readonly property ColorContext colorContext: ColorContext {
                id: titleTheme
                colorSet: ColorContext.View
                focused: titleButton.visualFocus
            }

            contentItem: Item {
                implicitWidth: titleLabel.implicitWidth + VLCStyle.dp(5 + 24, VLCStyle.scale)
                implicitHeight: Math.max(titleLabel.implicitHeight, VLCStyle.dp(24, VLCStyle.scale))

                T.Label {
                    id: titleLabel

                    anchors.verticalCenter: parent.verticalCenter
                    text: titleButton.text
                    font.pixelSize: VLCStyle.dp(MainCtx.gridView ? 20 : 16, VLCStyle.scale)
                    font.underline: titleButton.hovered
                    color: root._titleColor
                }

                // there is no right chevron glyph
                Widgets.IconLabel {
                    x: MainCtx.gridView ? titleLabel.width + VLCStyle.dp(5, VLCStyle.scale) : parent.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    text: VLCIcons.chevron_down
                    rotation: -90
                    font.pixelSize: width
                    color: root._titleColor
                }
            }

            background: Rectangle {
                color: "transparent"
                radius: VLCStyle.dp(4, VLCStyle.scale)
                border.color: titleButton.visualFocus ? titleTheme.visualFocus : "transparent"
            }

            Navigation.parentItem: root
            Navigation.downAction: () => root.setCurrentItemFocus(Qt.TabFocusReason)

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true
                    root.titleClicked(Qt.OtherFocusReason)
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            onClicked: root.titleClicked(Qt.MouseFocusReason)
        }

        Widgets.NavigableRow {
            id: cardRow

            focus: true
            visible: MainCtx.gridView
            width: parent.width
            topPadding: root._gap
            bottomPadding: root._gap
            spacing: root._gap

            Navigation.parentItem: root
            Navigation.upItem: titleButton

            Repeater {
                id: cards

                model: MainCtx.gridView ? root.model : null
                delegate: root.cardDelegate

                onItemAdded: (index, card) => {
                    card.activeFocusChanged.connect(() => {
                        if (card.activeFocus)
                            root.cardFocused(card.x + card.width / 2)
                    })
                }
            }
        }

        Widgets.NavigableCol {
            id: listCol

            visible: !MainCtx.gridView
            width: parent.width

            Navigation.parentItem: root
            Navigation.upItem: titleButton

            Repeater {
                id: rows

                model: MainCtx.gridView ? null : root.model
                delegate: root.listDelegate
            }
        }
    }
}
