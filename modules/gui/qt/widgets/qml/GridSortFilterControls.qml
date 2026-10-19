import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Dialogs

// The page header's right group (Figma 1040:2677 + "…" 2139:8916): sort, view, search, more
NavigableRow {
    id: root

    spacing: compact ? VLCStyle.dp(12, VLCStyle.scale) : VLCStyle.dp(20, VLCStyle.scale)

    // Escape pressed in the search field, after it was cleared
    signal escaped()

    // compact (two-row) header: the search field is PageExt's, this row only has the icon that opens it,
    // and the "…" button is PageExt's too (it calls openMore())
    property bool compact: false
    property bool searchOpen: false
    signal searchRequested()

    function openMore(button : Item) {
        _popup(moreMenu, button)
    }

    required property SortCtx sort
    required property SearchCtx search

    // FigmaMenu rows appended to the sort menu and to the "…" menu
    property var sortExtraRows: []
    property var menuExtraRows: []

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property bool _dark: theme.palette?.isDark ?? false

    // two rows per sortModel entry (ascending, descending), then the page's extras
    function _sortRows() : var {
        const rows = []
        const model = root.sort.model ?? []
        for (let i = 0; i < model.length; ++i) {
            const entry = model[i]
            for (const order of [Qt.AscendingOrder, Qt.DescendingOrder]) {
                rows.push({
                    text: Helpers.sortRowLabel(entry.criteria, entry.text, order),
                    checked: root.sort.criteria === entry.criteria && root.sort.order === order,
                    run: () => { root.sort.criteria = entry.criteria; root.sort.order = order }
                })
            }
        }
        return rows.concat(root.sortExtraRows)
    }

    function _popup(menu : FigmaMenu, button : Item) {
        menu.popup(button, button.width - menu.width, button.height + VLCStyle.margin_xxsmall)
    }

    IconToolButton {
        id: sortBtn

        anchors.verticalCenter: parent.verticalCenter
        visible: root.sort.available
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.topbar_sort
        description: qsTr("Sort")
        checked: sortMenu.visible

        onClicked: {
            sortMenu.rows = root._sortRows()
            root._popup(sortMenu, sortBtn)
        }

        FigmaMenu { id: sortMenu }
    }

    IconToolButton {
        id: viewBtn

        anchors.verticalCenter: parent.verticalCenter
        visible: MainCtx.hasGridListMode
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: MainCtx.gridView ? VLCIcons.grid : VLCIcons.list
        description: qsTr("View")
        checked: viewMenu.visible

        onClicked: root._popup(viewMenu, viewBtn)

        FigmaMenu {
            id: viewMenu

            width: VLCStyle.dp(265, VLCStyle.scale)
            rows: [
                { text: qsTr("Grid View"), icon: VLCIcons.grid, checked: MainCtx.gridView,
                  run: () => { MainCtx.gridView = true } },
                { text: qsTr("List View"), icon: VLCIcons.list, checked: !MainCtx.gridView,
                  run: () => { MainCtx.gridView = false } }
            ]
        }
    }

    // Figma 1040:2876: always visible, filters as you type
    SearchField {
        id: searchField

        visible: root.search.available && !root.compact
        searchCtx: root.search

        Navigation.parentItem: root
        onEscaped: root.escaped()
    }

    IconToolButton {
        id: searchBtn

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact && root.search.available
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.search
        description: qsTr("Search")
        checked: root.searchOpen

        onClicked: root.searchRequested()
    }

    IconToolButton {
        id: moreBtn

        anchors.verticalCenter: parent.verticalCenter
        visible: !root.compact
        enabled: visible
        width: VLCStyle.icon_normal
        height: VLCStyle.icon_normal
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.ellipsis
        description: qsTr("More")
        checked: moreMenu.visible

        onClicked: root._popup(moreMenu, moreBtn)

        FigmaMenu {
            id: moreMenu

            rows: [{ text: qsTr("Add File"), run: () => DialogsProvider.openFileDialog() }]
                  .concat(MainCtx.mediaLibraryAvailable ? [
                      { text: qsTr("Add Folder"), run: () => DialogsProvider.addFolderToLibrary() },
                      { text: qsTr("Rescan library"), run: () => MainCtx.mediaLibrary.reload() }
                  ] : [])
                  .concat(root.menuExtraRows)
        }
    }

    // Figma 1040:2876 field body; PageExt reuses it in the compact header
    component SearchField: T.TextField {
        id: searchField

        property SearchCtx searchCtx
        signal escaped()

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: ColorContext.View
        }
        readonly property bool _dark: theme.palette?.isDark ?? false

        enabled: visible
        width: VLCStyle.dp(325, VLCStyle.scale)
        height: VLCStyle.dp(34, VLCStyle.scale)
        leftPadding: VLCStyle.dp(8 + 24 + 10, VLCStyle.scale)
        rightPadding: VLCStyle.dp(8, VLCStyle.scale)
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        color: theme.fg.primary
        selectionColor: theme.bg.highlight
        selectedTextColor: theme.fg.highlight
        placeholderText: qsTr("Search")
        placeholderTextColor: searchField._dark ? "#404040" : theme.fg.secondary
        selectByMouse: true

        Accessible.name: qsTr("Search")

        background: Rectangle {
            color: searchField._dark ? "#151515" : theme.bg.secondary
            radius: VLCStyle.dp(6, VLCStyle.scale)
            border.width: searchField.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: theme.visualFocus

            IconLabel {
                x: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.search
                font.pixelSize: VLCStyle.icon_normal
                color: searchField._dark ? "#8F8F8F" : theme.fg.secondary
            }
        }

        // T.TextField draws no placeholder of its own
        T.Label {
            x: searchField.leftPadding
            width: searchField.width - searchField.leftPadding - searchField.rightPadding
            height: searchField.height
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !searchField.length && !searchField.preeditText
            text: searchField.placeholderText
            font: searchField.font
            color: searchField.placeholderTextColor
        }

        Binding {
            target: searchField.searchCtx
            property: "pattern"
            when: searchField.visible
            value: searchField.text
        }

        Connections {
            target: MainCtx.search
            function onAskShow() {
                if (searchField.visible)
                    searchField.forceActiveFocus(Qt.ShortcutFocusReason)
            }
        }

        Keys.onEscapePressed: (event) => {
            searchField.clear()
            searchField.escaped()
            event.accepted = true
        }
        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
    }
}
