
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
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

// titled tick list over a check-role model (roles display/checked), as in the Figma track panels
ColumnLayout {
    id: root

    property string title
    property var model: null
    property bool showNone: true
    // for models that select simultaneously (video): uncheck the other rows on selection
    property bool singleChoice: false
    property alias actions: actionRow.data

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }
    readonly property bool _dark: theme.palette.isDark
    readonly property color _labelColor: _dark ? "#969696" : theme.fg.primary

    // bumped on every model change so _anyChecked re-evaluates (the models have no notifier for it)
    property int _rev: 0
    readonly property bool _anyChecked: {
        void(_rev)
        if (!model)
            return false
        for (let i = 0; i < model.rowCount(); ++i)
            if (model.data(model.index(i, 0), Qt.CheckStateRole))
                return true
        return false
    }

    // the row keyboard focus starts on: the ticked one, else the first
    function focusRow() {
        if (noneRow.visible && noneRow.ticked)
            return noneRow
        for (let i = 0; i < rows.count; ++i)
            if (rows.itemAt(i).ticked)
                return rows.itemAt(i)
        return noneRow.visible ? noneRow : rows.itemAt(0)
    }

    // uncheck every checked row except `except`
    function _uncheckAll(except) {
        for (let i = 0; i < model.rowCount(); ++i) {
            const idx = model.index(i, 0)
            if (i !== except && model.data(idx, Qt.CheckStateRole))
                model.setData(idx, false, Qt.CheckStateRole)
        }
    }

    Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onDataChanged() { root._rev++ }
        function onRowsInserted() { root._rev++ }
        function onRowsRemoved() { root._rev++ }
        function onModelReset() { root._rev++ }
    }

    spacing: VLCStyle.dp(12, VLCStyle.scale)

    component TrackRow : T.ItemDelegate {
        id: row

        property bool ticked: false
        property color tickColor
        property color labelColor

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus

        Keys.onUpPressed: nextItemInFocusChain(false)?.forceActiveFocus(Qt.BacktabFocusReason)
        Keys.onDownPressed: nextItemInFocusChain(true)?.forceActiveFocus(Qt.TabFocusReason)
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        Accessible.role: Accessible.RadioButton
        Accessible.checked: ticked

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: (row.visualFocus || row.hovered) ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        contentItem: RowLayout {
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.IconLabel {
                Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: Text.AlignHCenter
                text: row.ticked ? VLCIcons.check : ""
                color: row.tickColor
                font.pixelSize: VLCStyle.icon_normal
            }

            Widgets.LabelExt {
                Layout.fillWidth: true
                text: row.text
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: row.labelColor
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(60, VLCStyle.scale) - root.spacing
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(28, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root._dark ? "#6B6B6B" : theme.fg.secondary
        }

        Row {
            id: actionRow
            spacing: VLCStyle.dp(12, VLCStyle.scale)
        }
    }

    TrackRow {
        id: noneRow

        visible: root.showNone && !!root.model
        text: qsTr("None")
        ticked: !root._anyChecked
        tickColor: theme.accent
        labelColor: root._labelColor
        onClicked: root._uncheckAll(-1)
    }

    Repeater {
        id: rows

        model: root.model

        delegate: TrackRow {
            required property var model
            required property int index

            text: model.display
            ticked: model.checked
            tickColor: theme.accent
            labelColor: root._labelColor
            onClicked: {
                if (model.checked)
                    return
                model.checked = true
                // the Figma list is single-choice; exclusive models already drop the old track
                if (root.singleChoice)
                    root._uncheckAll(index)
            }
        }
    }
}
