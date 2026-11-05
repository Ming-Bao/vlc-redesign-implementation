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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

import "HotkeysData.js" as HotkeysData

// Keyboard Shortcuts (Figma 2437:14832): the key-* options in sections, a hotkey and a global hotkey cell each. A cell
// captures the next key combination. Edits stay in a model loaded each time the dialog opens until Save.
// Single instance, opened by Dialogs.qml.
DialogCard {
    id: root

    // freshly loaded on each open, so that Cancel discards and a reset made meanwhile shows
    property var hk: null
    // bumped when a cell changes, so that the rows read it again
    property int rev: 0
    readonly property var fields: ["all", "action", "hotkey", "global"]
    property int fieldIndex: 0

    // section heads and rows, filtered; not rebuilt on an edit, so the list keeps its place
    readonly property var items: _build(hk, searchField.text, fieldIndex)

    readonly property real _cellWidth: VLCStyle.dp(270, VLCStyle.scale)
    readonly property real _rowHeight: VLCStyle.dp(33, VLCStyle.scale)
    readonly property real _margin: VLCStyle.dp(20, VLCStyle.scale)
    readonly property real _hotkeyX: VLCStyle.dp(398, VLCStyle.scale)

    title: qsTr("Keyboard Shortcuts")
    figmaWidth: 1048
    figmaHeight: 800
    modal: true
    saveEnabled: hk?.dirty ?? false
    footerNote: qsTr("Changes apply the next time VLC starts.")

    onCancelled: close()
    onSaved: {
        if (!saveEnabled)
            return
        hk.save()
        close()
    }
    onVisibleChanged: {
        if (!visible)
            return
        // reset the query before the model, so that items is not built twice
        hk = null
        searchField.text = ""
        fieldIndex = 0
        hk = DialogsProvider.loadHotkeyModel()
        list.positionViewAtBeginning()
        searchField.forceActiveFocus()
    }

    // the label the list shows for a model row
    function _labelOf(row) {
        const info = hk.rowAt(row)
        for (const s of HotkeysData.sections)
            for (const r of s.rows)
                if (r.option === info.option)
                    return r.label ?? info.label
        return info.label
    }

    function _build(model, text, field) {
        if (!model)
            return []
        const info = option => model.rowAt(model.rowOf(option))
        const labelOf = row => row.label ?? info(row.option).label
        const keysOf = (row, global) => model.displayKeys(info(row.option)[global ? "globalKeys" : "keys"])
        // an option this build does not have has no row
        const known = HotkeysData.sections.map(s => ({ title: s.title, rows: s.rows.filter(r => model.rowOf(r.option) >= 0) }))
        const flat = []
        HotkeysData.filter(known, labelOf, keysOf, text, fields[field]).forEach((s, i) => {
            flat.push({ head: s.title, first: i === 0 })
            for (const r of s.rows)
                flat.push({ option: r.option, label: labelOf(r) })
        })
        return flat
    }

    FontLoader { id: dmMono; source: "qrc:///DMMono-Regular.ttf" }

    Connections {
        target: root.hk
        function onDataChanged() { root.rev++ }
    }

    // search row, over the title bar's colour (Figma: the header is 96 high)
    Rectangle {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: VLCStyle.dp(46, VLCStyle.scale)
        color: root._s.topBar

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(820, VLCStyle.scale)
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
                source: "qrc:///redesign/settings/search.svg"
            }

            TextInput {
                id: searchField

                anchors.left: searchIcon.right
                anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                activeFocusOnTab: true
                clip: true
                selectByMouse: true
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.labelActive
                selectionColor: root._s.accentDim
                selectedTextColor: root._s.labelActive
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search Keyboard Shortcuts...")

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !searchField.text && !searchField.preeditText
                    text: qsTr("Search Keyboard Shortcuts...")
                    font: searchField.font
                    color: root._s.placeholder
                    Accessible.ignored: true
                }
            }
        }

        SettingCombo {
            colorContext.palette: VLCStyle.palette
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(200, VLCStyle.scale)
            height: VLCStyle.dp(34, VLCStyle.scale)
            textPadding: VLCStyle.dp(12, VLCStyle.scale)
            model: [ qsTr("All Fields"), qsTr("Actions"), qsTr("Hotkeys"), qsTr("Global Hotkeys") ]
            currentIndex: root.fieldIndex
            onActivated: (i) => root.fieldIndex = i
            Accessible.name: qsTr("Search in")
        }
    }

    // Action / Hotkey / Global Hotkey, and the divider
    Item {
        id: columns

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        height: VLCStyle.dp(63, VLCStyle.scale)

        // a click elsewhere ends a capture
        TapHandler { onTapped: root.takeFocus() }

        component ColumnTitle: Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._s.label
        }

        ColumnTitle { x: root._margin; text: qsTr("Action") }
        ColumnTitle {
            x: root._hotkeyX + (root._cellWidth - width) / 2
            text: qsTr("Hotkey")
        }
        ColumnTitle {
            x: parent.width - root._margin - root._cellWidth + (root._cellWidth - width) / 2
            text: qsTr("Global Hotkey")
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: root._margin
            anchors.right: parent.right
            anchors.rightMargin: root._margin
            anchors.bottom: parent.bottom
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: root._s.divider
        }
    }

    // a key combination field: click (or Enter) captures the next key, Delete clears
    component KeyCell: Rectangle {
        id: cell

        property int row
        property bool global
        property bool editable: true
        property string keys
        property bool capturing: false

        width: root._cellWidth
        height: root._rowHeight
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        opacity: editable ? 1 : 0.5
        border.width: activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: root._s.accent
        activeFocusOnTab: editable

        Accessible.role: Accessible.Button
        Accessible.name: capturing ? qsTr("Press a key…") : root.hk.displayKeys(keys)

        // leaving the cell ends a capture without a change
        onActiveFocusChanged: if (!activeFocus) capturing = false

        function _capture(event) {
            switch (event.key) {
            case Qt.Key_Shift: case Qt.Key_Control: case Qt.Key_Alt: case Qt.Key_Meta:
            case Qt.Key_AltGr: case Qt.Key_Super_L: case Qt.Key_Super_R:
                return
            }
            const key = root.hk.keyFromEvent(event.key, event.modifiers, event.text)
            if (!key)
                return
            capturing = false
            const other = root.hk.conflictRow(key, row, global)
            if (other >= 0)
                root.ask(qsTr("%1 is already used by %2. Reassign it?").arg(root.hk.displayKeys(key)).arg(root._labelOf(other)),
                         () => root.hk.assign(row, global, key), qsTr("Reassign"))
            else
                root.hk.assign(row, global, key)
        }

        // every key is accepted while capturing, Escape and Enter too, so that DialogCard does not act on them
        Keys.onPressed: (event) => {
            if (!editable)
                return
            if (capturing) {
                _capture(event)
                event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
                root.hk.clear(row, global)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                capturing = true
                event.accepted = true
            }
        }

        TapHandler {
            enabled: cell.editable
            onTapped: {
                cell.forceActiveFocus()
                cell.capturing = true
            }
        }

        Widgets.LabelExt {
            anchors.centerIn: parent
            text: cell.capturing ? qsTr("Press a key…") : root.hk.displayKeys(cell.keys)
            font.family: dmMono.name
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: cell.capturing ? root._s.accent : root._s.sectionTitle
        }

        Image {
            id: pencil

            visible: cell.editable
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(5, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(24, VLCStyle.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: "qrc:///redesign/dialogs/pencil.svg"

            HoverHandler { id: pencilHover }

            Widgets.ToolTipExt {
                colorContext.palette: VLCStyle.palette
                visible: pencilHover.hovered
                text: qsTr("Click, then press the new key. Delete clears it.")
            }
        }
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: columns.bottom
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        T.ScrollBar.vertical: Widgets.ScrollBarExt { colorContext.palette: VLCStyle.palette }

        // a click on anything but a cell (a label, a head, the background) ends a capture
        TapHandler {
            onTapped: (point) => {
                const d = list.itemAt(point.position.x + list.contentX, point.position.y + list.contentY)
                for (const c of d && !d.isHead ? [d.hotCell, d.globalCell] : []) {
                    if (c.contains(c.mapFromItem(list, point.position)))
                        return
                }
                root.takeFocus()
            }
        }

        delegate: Item {
            id: line

            required property var modelData
            readonly property bool isHead: modelData.head !== undefined
            readonly property int idx: isHead ? -1 : root.hk.rowOf(modelData.option)
            readonly property var info: (root.rev, isHead ? ({}) : root.hk.rowAt(idx))

            width: list.width
            // head: [10 gap, divider, 24 gap] when not first, 24 gap, 22 text, 23 gap; row: 33 + 14 gap
            height: isHead ? VLCStyle.dp((modelData.first ? 0 : 35) + 69, VLCStyle.scale) : root._rowHeight + VLCStyle.dp(14, VLCStyle.scale)

            Rectangle {
                visible: line.isHead && !line.modelData.first
                anchors.left: parent.left
                anchors.leftMargin: root._margin
                anchors.right: parent.right
                anchors.rightMargin: root._margin
                y: VLCStyle.dp(10, VLCStyle.scale)
                height: VLCStyle.dp(1, VLCStyle.scale)
                color: root._s.divider
            }

            Widgets.LabelExt {
                visible: line.isHead
                x: root._margin
                y: VLCStyle.dp(line.modelData.first ? 24 : 59, VLCStyle.scale)
                text: line.isHead ? line.modelData.head : ""
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root._s.title
                Accessible.role: Accessible.Heading
            }

            Widgets.LabelExt {
                visible: !line.isHead
                x: root._margin
                width: root._hotkeyX - root._margin - VLCStyle.dp(10, VLCStyle.scale)
                height: root._rowHeight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: line.isHead ? "" : line.modelData.label
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._s.sectionTitle
            }

            readonly property Item hotCell: hotCell
            readonly property Item globalCell: globalCell

            KeyCell {
                id: hotCell
                visible: !line.isHead
                x: root._hotkeyX
                row: line.idx
                global: false
                keys: line.info.keys ?? ""
            }

            // a row without a global option has nothing to write the cell to
            KeyCell {
                id: globalCell
                visible: !line.isHead
                x: line.width - root._margin - width
                row: line.idx
                global: true
                editable: line.info.hasGlobal ?? false
                keys: line.info.globalKeys ?? ""
            }
        }
    }
}
