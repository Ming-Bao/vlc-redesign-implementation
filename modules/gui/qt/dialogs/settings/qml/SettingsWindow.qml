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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

import "SettingsData.js" as SettingsData

// The Figma settings window (frames "Settings - *", 1048 x 865): a DialogCard without footer, whose title bar holds
// the search box and the page title, with a sidebar of pages and the page content. Single instance, opened by
// MainInterface.qml.
DialogCard {
    id: root

    // the selected page, an index into SettingsData.pages; kept for the session (the Loader in MainInterface.qml stays
    // active)
    property int currentPage: 0
    property string searchText: ""
    // what the content area shows for the current page
    property Component pageComponent: Component {
        SettingsWindowPage {
            page: root.pages[root.currentPage]
            results: root.searchText.trim() ? SettingsData.search(root.pages, root.searchText) : null
        }
    }

    readonly property var pages: SettingsData.pages

    title: qsTr("Settings")
    figmaWidth: 1048
    figmaHeight: 865
    minFigmaWidth: 760
    minFigmaHeight: 480
    resizable: true
    showFooter: false
    cardColor: _s.windowBg
    headerTitle: pages[currentPage].title
    titleSize: VLCStyle.dp(16, VLCStyle.scale)
    titleColor: _s.title
    titleLeftMargin: VLCStyle.dp(32, VLCStyle.scale)
    barPadding: VLCStyle.dp(14, VLCStyle.scale)

    // Tab goes sidebar, search, close, content
    afterHeader: content

    onCancelled: close()
    onClosing: {
        // a field being edited commits on focus loss: take the focus first, so that the save has its value
        takeFocus()
        SettingsBridge.save()
    }
    // values may have changed while the window was closed
    onVisibleChanged: {
        if (!visible)
            return
        pageLoader.item?.reload?.()
        if (!activeFocusItem) {
            sidebar.quietFocus = true
            sidebar.forceActiveFocus()
        }
    }

    headerExtra: Item {
        implicitWidth: VLCStyle.dp(8, VLCStyle.scale) + searchBox.width
        implicitHeight: searchBox.height
        readonly property Item field: searchField

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(200, VLCStyle.scale)
            height: VLCStyle.dp(34, VLCStyle.scale)

            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root._s.searchBg

            Image {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(24, VLCStyle.scale)
                height: width
                sourceSize: Qt.size(width, height)
                source: Helpers.themedSvg(root.colorContext.palette, "qrc:///redesign/settings/search.svg")
            }

            TextInput {
                id: searchField

                anchors.left: searchIcon.right
                anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                activeFocusOnTab: true
                KeyNavigation.backtab: sidebar
                clip: true
                selectByMouse: true
                text: root.searchText
                onTextEdited: root.searchText = text

                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.labelActive
                selectionColor: root._s.accentDim
                selectedTextColor: root._s.labelActive

                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search")

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !searchField.text && !searchField.preeditText
                    text: qsTr("Search")
                    font: searchField.font
                    color: root._s.placeholder
                    Accessible.ignored: true
                }
            }
        }
    }

    // first in the body, so that Tab starts here; the KeyNavigation entries make it go sidebar, search, close, content
    SettingsSidebar {
        id: sidebar

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        KeyNavigation.tab: root.headerItem?.field ?? null
        style: root._s
        pages: root.pages
        currentIndex: root.searchText.trim() ? -1 : root.currentPage
        onPicked: (index) => {
            root.searchText = ""
            root.currentPage = index
        }
    }

    // the page
    FocusScope {
        id: content

        KeyNavigation.backtab: root.closeItem

        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        activeFocusOnTab: true

        Loader {
            id: pageLoader
            anchors.fill: parent
            focus: true
            sourceComponent: root.pageComponent
        }
    }
}
