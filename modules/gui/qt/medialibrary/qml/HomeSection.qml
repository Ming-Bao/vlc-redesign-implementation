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

// A Home row (Figma 6261:15142): "Title ›" over one line of cards
FocusScope {
    id: root

    property string title
    // an ML model (whose `limit` the page binds to `fit`) or a JS array
    property var model
    property Component cardDelegate
    property Component listDelegate // list view (not used yet)
    property real cardWidth
    // centre x (card row coordinates, the same in every section) of the card focused
    // last on the page, so that moving between rows keeps the column
    property real focusX: 0

    readonly property real _gap: VLCStyle.dp(20, VLCStyle.scale)

    // number of cards that fit the width on one line
    readonly property int fit: Math.max(1, Math.floor((width + _gap) / (cardWidth + _gap)))

    signal titleClicked(int reason)
    signal cardFocused(real x)

    // focus the card nearest `focusX`
    function setCurrentItemFocus(reason) {
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

    visible: cards.count > 0

    implicitHeight: column.implicitHeight

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property color _titleColor: theme.palette?.isDark ? "#969696" : theme.fg.primary

    Column {
        id: column

        width: parent.width
        topPadding: root._gap
        bottomPadding: root._gap

        T.AbstractButton {
            id: titleButton

            focusPolicy: Qt.StrongFocus
            text: root.title

            implicitWidth: implicitContentWidth
            implicitHeight: implicitContentHeight

            readonly property ColorContext colorContext: ColorContext {
                id: titleTheme
                colorSet: ColorContext.View
                focused: titleButton.visualFocus
            }

            contentItem: Row {
                spacing: VLCStyle.dp(5, VLCStyle.scale)

                T.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: titleButton.text
                    font.pixelSize: VLCStyle.dp(20, VLCStyle.scale)
                    font.underline: titleButton.hovered
                    color: root._titleColor
                }

                // there is no right chevron glyph
                Widgets.IconLabel {
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
            width: parent.width
            topPadding: root._gap
            bottomPadding: root._gap
            spacing: root._gap

            Navigation.parentItem: root
            Navigation.upItem: titleButton

            Repeater {
                id: cards

                model: root.model
                delegate: root.cardDelegate

                onItemAdded: (index, card) => {
                    card.activeFocusChanged.connect(() => {
                        if (card.activeFocus)
                            root.cardFocused(card.x + card.width / 2)
                    })
                }
            }
        }
    }
}
