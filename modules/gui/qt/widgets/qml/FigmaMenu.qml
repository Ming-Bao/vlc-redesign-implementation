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
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQml.Models

import VLC.MainInterface
import VLC.Style

// The redesign's popup menu (Figma "View Options" 858:3290, "Sorting Options" 856:2215).
// rows: [{ text, icon (glyph, optional), checked (optional), enabled (optional), run (function, optional) }]
T.Menu {
    id: root

    property var rows: []

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        // a Menu is not an Item, so the context cannot inherit the palette from the page
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette?.isDark ?? false

    width: VLCStyle.dp(295, VLCStyle.scale)
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
    padding: VLCStyle.dp(4, VLCStyle.scale)
    margins: VLCStyle.margin_xsmall

    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        interactive: Window.window ? contentHeight + root.topPadding + root.bottomPadding > Window.window.height
                                   : false
        clip: true
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    background: Rectangle {
        radius: VLCStyle.dp(10, VLCStyle.scale)
        // ponytail: no 50 px backdrop blur; at 95 % opacity it does not show. Add a FrostedGlassEffect if the card gets lighter.
        color: root._dark ? Qt.rgba(25 / 255, 25 / 255, 25 / 255, 0.95) : theme.bg.primary

        // Figma: 0 8 15 rgba(0,0,0,0.46)
        RoundedRectangleShadow {
            color: Qt.rgba(0, 0, 0, 0.46)
            blurRadius: VLCStyle.dp(15, VLCStyle.scale)
            yOffset: VLCStyle.dp(8, VLCStyle.scale)
            implicitWidth: parent.width + blurRadius * compensationFactor * 2
            implicitHeight: parent.height + blurRadius * compensationFactor * 2
        }
    }

    Instantiator {
        model: root.rows

        delegate: T.MenuItem {
            id: item

            required property var modelData
            required property int index

            text: modelData.text
            enabled: modelData.enabled ?? true

            implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
            leftPadding: VLCStyle.dp(14, VLCStyle.scale)
            rightPadding: VLCStyle.dp(14, VLCStyle.scale)
            topPadding: VLCStyle.dp(2, VLCStyle.scale)
            bottomPadding: VLCStyle.dp(2, VLCStyle.scale)

            contentItem: RowLayout {
                spacing: VLCStyle.dp(10, VLCStyle.scale)
                opacity: item.enabled ? 1 : 0.4

                IconLabel {
                    visible: !!item.modelData.icon
                    text: item.modelData.icon ?? ""
                    font.pixelSize: VLCStyle.icon_normal
                    color: label.color
                }

                T.Label {
                    id: label
                    Layout.fillWidth: true
                    text: item.text
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: root._dark ? "#8F8F8F" : theme.fg.primary
                }

                IconLabel {
                    visible: !!item.modelData.checked
                    text: VLCIcons.checkmark
                    font.pixelSize: VLCStyle.icon_normal
                    color: root._dark ? "#D37918" : theme.accent
                }
            }

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: item.highlighted ? (root._dark ? "#1F1F1F" : theme.bg.secondary) : "transparent"
            }

            // later: run once the menu has closed, so a modal dialog does not nest inside the menu's event handling
            onTriggered: if (modelData.run) Qt.callLater(modelData.run)
        }

        onObjectAdded: (index, object) => root.insertItem(index, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }
}
