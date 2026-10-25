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
import "SettingsData.js" as SettingsData

// Network's Buffering block: the Low / Normal / High / Custom dropdown, then the four caching fields (ms). A preset
// is relative to each option's default (half, as is, twice); the dropdown shows the preset all four values match,
// else Custom, and the fields are enabled only on Custom.
Column {
    id: root

    required property var row
    property Item delegate              // the SettingsRowDelegate (set by it): rev, value, style
    readonly property bool fullRow: true
    readonly property var style: delegate ? delegate.style : null

    readonly property var fields: [
        { label: qsTr("Local files"), option: "file-caching" },
        { label: qsTr("Discs"), option: "disc-caching" },
        { label: qsTr("Network streams"), option: "network-caching" },
        { label: qsTr("Live capture"), option: "live-caching" }
    ]
    readonly property var presets: ["low", "normal", "high", "custom"]
    readonly property var _factor: ({ low: 0.5, normal: 1, high: 2 })
    // Custom picked by hand stays Custom even while the values happen to match a preset
    property bool pickedCustom: false

    readonly property string preset: {
        void(delegate ? delegate.rev : 0)
        if (pickedCustom)
            return "custom"
        return SettingsData.presetFor(fields.map((f) => Number(SettingsBridge.value(f.option))),
                                      fields.map((f) => Number(SettingsBridge.defaultValue(f.option))))
    }
    readonly property real _lineHeight: VLCStyle.dp(46, VLCStyle.scale)
    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    function _pick(name) {
        pickedCustom = name === "custom"
        if (pickedCustom)
            return
        for (const f of fields)
            SettingsBridge.setValue(f.option, Math.round(SettingsBridge.defaultValue(f.option) * _factor[name]))
    }

    Item {
        width: root.width
        height: root._lineHeight

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style ? root.style.rowLabel : "transparent"
        }

        SettingCombo {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root._controlWidth
            height: VLCStyle.dp(36, VLCStyle.scale)
            textPadding: VLCStyle.dp(14, VLCStyle.scale)
            model: [ qsTr("Low"), qsTr("Normal"), qsTr("High"), qsTr("Custom") ]
            currentIndex: root.presets.indexOf(root.preset)
            onActivated: (i) => root._pick(root.presets[i])
            Accessible.name: root.row.label
        }
    }

    Repeater {
        model: root.fields

        Item {
            id: line

            required property var modelData
            readonly property bool active: root.preset === "custom"

            width: root.width
            height: root._lineHeight
            visible: SettingsBridge.exists(modelData.option)

            Widgets.LabelExt {
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.label
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root.style ? root.style.rowLabel : "transparent"
                opacity: line.active || !root.style ? 1.0 : root.style.disabledOpacity
            }

            SettingField {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root._controlWidth
                enabled: line.active
                suffix: " ms"
                committedText: {
                    void(root.delegate ? root.delegate.rev : 0)
                    return String(SettingsBridge.value(line.modelData.option))
                }
                onCommitted: (t) => {
                    if (t.length && !isNaN(Number(t)))
                        SettingsBridge.setValue(line.modelData.option, Number(t))
                }
                Accessible.name: line.modelData.label
            }
        }
    }
}
