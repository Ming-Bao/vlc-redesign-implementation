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
import VLC.Playlist

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
    property int itemCount: (typeof _firstChild?.count === "number") ? _firstChild.count : -1

    property var sortModel: _firstChild?.sortModel ?? null

    // FigmaMenu rows the page adds to its sort menu and to its header "…" menu
    property var sortExtraRows: []
    property var headerMenuRows: []

    // crumbs of the header: [{ title, path, props (optional History properties) }]
    property var breadcrumbs: Helpers.breadcrumbs(pagePrefix, title, _crumbLabels)

    readonly property var _crumbLabels: ({
        "home": qsTr("Home"),
        "video": qsTr("Videos"),
        "music": qsTr("Music"),
        "music/artists": qsTr("Artists"),
        "music/albums": qsTr("Albums"),
        "music/genres": qsTr("Genres"),
        "music/songs": qsTr("Songs"),
        "network": qsTr("Network"),
        "playlists": qsTr("Playlists"),
        "recent": qsTr("Recent")
    })

    // two-row header (and the library pages inside the player's side panel)
    readonly property bool compact: width < VLCStyle.dp(600, VLCStyle.scale)

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
        _firstChild.Navigation.upItem = Qt.binding(() => root.header)
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
        compact: root.compact
        itemCount: root.itemCount

        leftPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_left_margin + root.leftPadding
        rightPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_right_margin + root.rightPadding

        sortExtraRows: root.sortExtraRows
        headerMenuRows: root.headerMenuRows

        search: _searchCtx
        sort: _sortCtx

        Navigation.parentItem: root
        Navigation.downAction: focusContent

        function focusContent() {
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
        property bool compact: false
        property bool _searchOpen: false

        property alias sortExtraRows: gridSortFilter.sortExtraRows
        property alias headerMenuRows: gridSortFilter.menuExtraRows

        property alias search: gridSortFilter.search
        property alias sort: gridSortFilter.sort

        function _openSearch() {
            _searchOpen = true
            compactSearch.forceActiveFocus(Qt.MouseFocusReason)
        }

        function _closeSearch() {
            compactSearch.clear()
            _searchOpen = false
            gridSortFilter.forceActiveFocus(Qt.BacktabFocusReason)
        }

        Connections {
            target: MainCtx.search
            function onAskShow() {
                if (defaultPageHeader.compact && gridSortFilter.search.available)
                    defaultPageHeader._openSearch()
            }
        }

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

            // wide: one row; compact: row 1 = nav + crumbs + "…" + open-in-library, row 2 = count/search + sort, view, search
            GridLayout {
                id: row

                Layout.fillWidth: true
                columnSpacing: defaultPageHeader.compact ? VLCStyle.dp(12, VLCStyle.scale) : VLCStyle.dp(20, VLCStyle.scale)
                rowSpacing: VLCStyle.dp(20, VLCStyle.scale)

                RowLayout {
                    Layout.fillWidth: true
                    Layout.row: 0
                    Layout.column: 0
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
                        Navigation.rightItem: defaultPageHeader.compact ? moreBtn : gridSortFilter
                        Navigation.downItem: defaultPageHeader.compact ? gridSortFilter : null

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
                    visible: defaultPageHeader.itemCount >= 0 && !(defaultPageHeader.compact && defaultPageHeader._searchOpen)
                    Layout.row: defaultPageHeader.compact ? 1 : 0
                    Layout.column: defaultPageHeader.compact ? 0 : 1
                    Layout.fillWidth: defaultPageHeader.compact
                    text: qsTr("%1 item", "%1 items", defaultPageHeader.itemCount).arg(defaultPageHeader.itemCount)
                    color: theme.palette?.isDark ? "#6B6B6B" : theme.fg.secondary.alpha(0.75)
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }

                // compact only: replaces the count while searching
                GridSortFilterControls.SearchField {
                    id: compactSearch

                    visible: defaultPageHeader.compact && defaultPageHeader._searchOpen && gridSortFilter.search.available
                    Layout.row: 1
                    Layout.column: 0
                    Layout.fillWidth: true
                    height: VLCStyle.dp(24, VLCStyle.scale)
                    searchCtx: _searchCtx

                    Navigation.parentItem: defaultPageHeader
                    Navigation.rightItem: gridSortFilter
                    Navigation.upItem: crumbRow

                    onEscaped: defaultPageHeader._closeSearch()
                    // leaving the field while it is empty folds it back
                    onActiveFocusChanged: if (!activeFocus && !length) defaultPageHeader._searchOpen = false
                }

                // keeps the row-2 group 96 wide while row 1 only has two buttons
                Item {
                    visible: defaultPageHeader.compact
                    Layout.row: 0
                    Layout.column: 1
                    implicitWidth: VLCStyle.icon_normal
                    implicitHeight: VLCStyle.icon_normal
                }

                IconToolButton {
                    id: moreBtn

                    visible: defaultPageHeader.compact
                    enabled: visible
                    Layout.row: 0
                    Layout.column: openBtn.visible ? 2 : 3     // right-aligned without the ↗
                    implicitWidth: VLCStyle.icon_normal
                    implicitHeight: VLCStyle.icon_normal
                    font.pixelSize: VLCStyle.icon_normal
                    text: VLCIcons.ellipsis
                    description: qsTr("More")

                    Navigation.parentItem: defaultPageHeader
                    Navigation.leftItem: crumbRow
                    Navigation.rightItem: openBtn
                    Navigation.downItem: gridSortFilter

                    onClicked: gridSortFilter.openMore(moreBtn)
                }

                GridSortFilterControls {
                    id: gridSortFilter

                    Layout.row: defaultPageHeader.compact ? 1 : 0
                    Layout.column: defaultPageHeader.compact ? 1 : 2
                    Layout.columnSpan: defaultPageHeader.compact ? 3 : 1
                    Layout.alignment: Qt.AlignRight
                    focus: true
                    sort: _sortCtx
                    search: _searchCtx
                    compact: defaultPageHeader.compact
                    searchOpen: defaultPageHeader._searchOpen
                    Navigation.parentItem: defaultPageHeader
                    Navigation.leftItem: defaultPageHeader.compact && compactSearch.visible ? compactSearch : crumbRow
                    Navigation.rightItem: openBtn.visible ? openBtn : null
                    Navigation.upItem: crumbRow

                    onSearchRequested: defaultPageHeader._openSearch()
                    onEscaped: defaultPageHeader.Navigation.defaultNavigationDown()
                }

                // Figma 848:1995 "Open in library", only shown in the player's side panel
                IconToolButton {
                    id: openBtn

                    visible: MainCtx.playerView
                    enabled: visible
                    Layout.row: 0
                    Layout.column: 3
                    implicitWidth: VLCStyle.icon_normal
                    implicitHeight: VLCStyle.icon_normal
                    font.pixelSize: VLCStyle.icon_normal
                    text: VLCIcons.open_in_library
                    description: qsTr("Open in library")

                    Navigation.parentItem: defaultPageHeader
                    Navigation.leftItem: defaultPageHeader.compact ? moreBtn : gridSortFilter
                    Navigation.downItem: defaultPageHeader.compact ? gridSortFilter : null

                    // twin of Player.qml's leavePlayer()
                    onClicked: {
                        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP)
                            MainPlaylistController.stop()
                        MainCtx.playerView = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
                color: theme.separator
            }
        }
    }
}
