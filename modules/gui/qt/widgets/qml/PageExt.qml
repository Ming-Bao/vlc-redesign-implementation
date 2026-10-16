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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util

T.Page {
    id: root

    //path of the current page loader
    property var pagePrefix: []

    //note that T.Page introduce an intermediate Item, so to access our delegate,
    //we need to use contentChildren[0] rather than contentItem
    readonly property Item _firstChild: contentChildren[0] ?? null

    //indicates whether the subview support grid/list mode
    property bool hasGridListMode: _firstChild?.hasGridListMode ?? false

    property bool isSearchable: _firstChild?.isSearchable ?? false

    // number of items in the current subview, -1 when the subview has no model count
    readonly property int itemCount: (typeof _firstChild?.count === "number") ? _firstChild.count : -1

    property var sortModel: _firstChild?.sortModel ?? null

    // FigmaMenu rows the page adds to its sort menu and to its header "…" menu
    property var sortExtraRows: []
    property var headerMenuRows: []

    // crumbs of the header: [{ title, path, props (optional History properties) }]
    property var breadcrumbs: Helpers.breadcrumbs(pagePrefix, title, _crumbLabels)

    readonly property var _crumbLabels: ({
        "home": qsTr("Home"),
        "video": qsTr("Videos"),
        "video/playlists": qsTr("Playlists"),
        "music": qsTr("Music"),
        "music/artists": qsTr("Artists"),
        "music/albums": qsTr("Albums"),
        "music/tracks": qsTr("Tracks"),
        "music/genres": qsTr("Genres"),
        "music/playlists": qsTr("Playlists"),
        "network": qsTr("Network"),
        "playlists": qsTr("Playlists"),
        "recent": qsTr("Recent")
    })

    // ponytail: the old sidebar sub-items, shown as tabs under the header until 4c replaces Videos/Music browsing
    readonly property var _tabs: ({
        "video": [{ name: "all", text: qsTr("All") }, { name: "playlists", text: qsTr("Playlists") }],
        "music": [{ name: "artists", text: qsTr("Artists") }, { name: "albums", text: qsTr("Albums") },
                  { name: "tracks", text: qsTr("Tracks") }, { name: "genres", text: qsTr("Genres") },
                  { name: "playlists", text: qsTr("Playlists") }]
    })[pagePrefix[0]] ?? []

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    readonly property SearchCtx search: _searchCtx
    readonly property SortCtx sort: _sortCtx


    SearchCtx {
        id: _searchCtx
        available: root.isSearchable
    }

    SortCtx {
        id: _sortCtx

        readonly property string _sortCriteriaKey: ["sortCriteria", ...root.pagePrefix].join("/")
        readonly property string _sortOrderKey:  ["sortOrder", ...root.pagePrefix].join("/")

        available: Helpers.isArray(root.sortModel) && (root.sortModel).length > 0
        model: root.sortModel

        //save & restore setting of the page
        Component.onCompleted: {
            const criteria = MainCtx.settingValue(_sortCriteriaKey, undefined)
            if (criteria !== undefined)
                _sortCtx.criteria = criteria

            const order = MainCtx.settingValue(_sortOrderKey, undefined)
            if (order !== undefined)
                _sortCtx.order = parseInt(order)
        }

        Component.onDestruction: {
            MainCtx.setSettingValue(_sortCriteriaKey, _sortCtx.criteria)
            MainCtx.setSettingValue(_sortOrderKey, _sortCtx.order)
        }
    }

    Binding {
        target: MainCtx
        property: "hasGridListMode";
        value: root.hasGridListMode
    }

    on_FirstChildChanged: {
        if (!_firstChild)
            return
        _firstChild.Navigation.parentItem = root
        _firstChild.Navigation.upItem = root.header
    }

    function positionContentAtBeginning() {
        _firstChild?.positionContentAtBeginning?.()
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))

    header: DefaultPageHeader {
        breadcrumbs: root.breadcrumbs
        tabs: root._tabs
        tabRoot: root.pagePrefix[0] ?? ""
        currentTab: root.pagePrefix[1] ?? ""
        itemCount: root.itemCount

        leftPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_left_margin + root.leftPadding
        rightPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_right_margin + root.rightPadding

        sortExtraRows: root.sortExtraRows
        headerMenuRows: root.headerMenuRows

        search: _searchCtx
        sort: _sortCtx

        Navigation.parentItem: root
        Navigation.downAction: function() {
            if (typeof root.setCurrentItemFocus === "function")
                root.setCurrentItemFocus(Qt.TabFocusReason)
            else if (typeof root._firstChild?.setCurrentItemFocus === "function")
             root._firstChild.setCurrentItemFocus(Qt.TabFocusReason)
            else if (root._firstChild)
                root._firstChild.forceActiveFocus(Qt.TabFocusReason)
        }
    }

    component DefaultPageHeader: T.ToolBar {
        id: defaultPageHeader

        // Properties
        property var breadcrumbs: []
        property var tabs: []
        property string tabRoot: ""
        property string currentTab: ""

        readonly property bool _dark: theme.palette?.isDark ?? false

        // leading crumbs folded into one "…" crumb so the rest fits
        readonly property int _hiddenCrumbs: {
            const list = breadcrumbs
            if (list.length < 2)
                return 0
            const sep = VLCStyle.dp(8 + 2 * 6, VLCStyle.scale)      // "▶" plus its two gaps
            const fold = crumbFont.advanceWidth("…") + sep
            let used = lastCrumbFont.advanceWidth(list[list.length - 1].title)
            let n = list.length - 1
            while (n > 0) {
                const next = crumbFont.advanceWidth(list[n - 1].title) + sep
                if (used + next + (n > 1 ? fold : 0) > crumbRow.width)
                    break
                used += next
                --n
            }
            return n
        }

        readonly property var _shownCrumbs: {
            const n = _hiddenCrumbs
            if (n === 0)
                return breadcrumbs
            const up = breadcrumbs[n - 1]
            return [{ title: "…", path: up.path, props: up.props }].concat(breadcrumbs.slice(n))
        }

        FontMetrics { id: crumbFont; font.pixelSize: VLCStyle.dp(16, VLCStyle.scale) }
        FontMetrics { id: lastCrumbFont; font.pixelSize: VLCStyle.dp(16, VLCStyle.scale); font.weight: Font.DemiBold }

        property int itemCount: -1

        property alias sortExtraRows: gridSortFilter.sortExtraRows
        property alias headerMenuRows: gridSortFilter.menuExtraRows

        property alias search: gridSortFilter.search
        property alias sort: gridSortFilter.sort

        position: T.ToolBar.Header

        topPadding: VLCStyle.dp(20, VLCStyle.scale)
        bottomPadding: VLCStyle.dp(17, VLCStyle.scale)

        // FIXME: `GridItem`'s background extends beyond its
        //        bounding rect, violating the hypothetical
        //        clip test (see 7e6b23db).
        bottomInset: (MainCtx.hasGridListMode && MainCtx.gridView) ? VLCStyle.gridItemSelectedBorder : undefined

        // Settings

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                 implicitContentHeight + topPadding + bottomPadding)

        // Children

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: ColorContext.View
        }

        background: Rectangle {
            color: theme.bg.primary
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: VLCStyle.dp(17, VLCStyle.scale)

            RowLayout {
                id: row

                Layout.fillWidth: true
                spacing: VLCStyle.dp(20, VLCStyle.scale)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(10, VLCStyle.scale)

                    Row {
                        spacing: VLCStyle.dp(12, VLCStyle.scale)

                        IconToolButton {
                            id: backBtn

                            width: VLCStyle.icon_normal
                            height: VLCStyle.icon_normal
                            text: VLCIcons.back
                            description: qsTr("Previous")
                            font.pixelSize: VLCStyle.icon_normal
                            enabled: !History.previousEmpty
                            opacity: enabled ? 1.0 : 0.3

                            Navigation.parentItem: defaultPageHeader
                            Navigation.rightItem: forwardBtn
                            Navigation.downItem: tabRow.visible ? tabRow : null

                            onClicked: History.previous()
                        }

                        IconToolButton {
                            id: forwardBtn

                            width: VLCStyle.icon_normal
                            height: VLCStyle.icon_normal
                            text: VLCIcons.back
                            rotation: 180
                            description: qsTr("Next")
                            font.pixelSize: VLCStyle.icon_normal
                            enabled: !History.nextEmpty
                            opacity: enabled ? 1.0 : 0.3

                            Navigation.parentItem: defaultPageHeader
                            Navigation.leftItem: backBtn
                            Navigation.rightItem: crumbRow
                            Navigation.downItem: tabRow.visible ? tabRow : null

                            onClicked: History.next()
                        }
                    }

                    // Figma 6153:13642
                    NavigableRow {
                        id: crumbRow

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        clip: true
                        spacing: VLCStyle.dp(6, VLCStyle.scale)

                        Navigation.parentItem: defaultPageHeader
                        Navigation.leftItem: forwardBtn
                        Navigation.rightItem: gridSortFilter
                        Navigation.downItem: tabRow.visible ? tabRow : null

                        Repeater {
                            id: crumbRepeater

                            model: defaultPageHeader._shownCrumbs

                            delegate: T.AbstractButton {
                                id: crumb

                                required property var modelData
                                required property int index
                                readonly property bool isLast: index === defaultPageHeader._shownCrumbs.length - 1

                                enabled: !isLast
                                focusPolicy: Qt.StrongFocus
                                text: modelData.title

                                implicitWidth: implicitContentWidth
                                implicitHeight: implicitContentHeight

                                // the focus ring colour only exists in a focused context
                                readonly property ColorContext colorContext: ColorContext {
                                    id: crumbTheme
                                    colorSet: ColorContext.View
                                    focused: crumb.visualFocus
                                }

                                contentItem: Row {
                                    spacing: VLCStyle.dp(6, VLCStyle.scale)

                                    T.Label {
                                        visible: crumb.index > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: VLCStyle.dp(8, VLCStyle.scale)
                                        text: "▶"
                                        font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
                                        color: defaultPageHeader._dark ? "#404040" : theme.fg.secondary
                                    }

                                    T.Label {
                                        // a too-long crumb ends in "…" instead of being cut by crumbRow
                                        width: Math.min(implicitWidth, Math.max(0, crumbRow.width - crumb.x - (crumb.index > 0 ? VLCStyle.dp(8 + 6, VLCStyle.scale) : 0)))
                                        elide: Text.ElideRight
                                        text: crumb.text
                                        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                        font.weight: crumb.isLast ? Font.DemiBold : Font.Normal
                                        font.underline: crumb.hovered && !crumb.isLast
                                        color: defaultPageHeader._dark ? (crumb.isLast ? "#969696" : "#8F8F8F")
                                                                       : (crumb.isLast ? theme.fg.primary : theme.fg.secondary)
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                    radius: VLCStyle.dp(4, VLCStyle.scale)
                                    border.color: crumb.visualFocus ? crumbTheme.visualFocus : "transparent"
                                }

                                Keys.priority: Keys.AfterItem
                                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                                onClicked: {
                                    if (crumb.modelData.props)
                                        History.push(crumb.modelData.path, crumb.modelData.props)
                                    else
                                        History.push(crumb.modelData.path)
                                }
                            }
                        }
                    }
                }

                T.Label {
                    visible: defaultPageHeader.itemCount >= 0
                    text: qsTr("%1 item", "%1 items", defaultPageHeader.itemCount).arg(defaultPageHeader.itemCount)
                    color: theme.palette?.isDark ? "#6B6B6B" : theme.fg.secondary.alpha(0.75)
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }

                GridSortFilterControls {
                    id: gridSortFilter
                    focus: true
                    sort: _sortCtx
                    search: _searchCtx
                    Navigation.parentItem: defaultPageHeader
                    Navigation.leftItem: crumbRow
                    Navigation.downItem: tabRow.visible ? tabRow : null
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
                color: theme.separator
            }

            // ponytail: temporary (until 4c) tabs for the old Videos/Music sidebar sub-items
            NavigableRow {
                id: tabRow

                visible: defaultPageHeader.tabs.length > 0
                Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)

                Navigation.parentItem: defaultPageHeader
                Navigation.upItem: gridSortFilter

                Repeater {
                    model: defaultPageHeader.tabs

                    delegate: T.TabButton {
                        id: tab

                        required property var modelData
                        readonly property bool selected: modelData.name === defaultPageHeader.currentTab

                        text: modelData.text
                        height: VLCStyle.dp(40, VLCStyle.scale)
                        leftPadding: VLCStyle.dp(16, VLCStyle.scale)
                        rightPadding: VLCStyle.dp(16, VLCStyle.scale)
                        implicitWidth: implicitContentWidth + leftPadding + rightPadding
                        focusPolicy: Qt.StrongFocus

                        readonly property ColorContext colorContext: ColorContext {
                            id: tabTheme
                            colorSet: ColorContext.View
                            focused: tab.visualFocus
                        }

                        contentItem: T.Label {
                            text: tab.text
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: defaultPageHeader._dark ? (tab.selected ? "#C6C6C6" : "#8F8F8F")
                                                           : (tab.selected ? theme.fg.primary : theme.fg.secondary)
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: tab.visualFocus ? tabTheme.visualFocus : "transparent"

                            Rectangle {
                                visible: tab.selected
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: defaultPageHeader._dark ? "#D37918" : theme.accent
                            }
                        }

                        Keys.priority: Keys.AfterItem
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                        onClicked: History.push([defaultPageHeader.tabRoot, modelData.name])
                    }
                }
            }
        }
    }
}
