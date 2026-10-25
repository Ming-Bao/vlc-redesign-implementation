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

// One settings row from SettingsData.js (see the schema there): the label and its info glyph on the left, the
// control in a 320 px column on the right. Reads its option again whenever SettingsBridge.revision or reloadTick
// changes; writes on every change (fields on editingFinished: Enter, focus loss, the window closing).
FocusScope {
    id: root

    required property var row
    // the page bumps it to re-read values changed outside the bridge (the player, the legacy dialog)
    property int reloadTick: 0

    readonly property int rev: SettingsBridge.revision + reloadTick
    readonly property bool shown: SettingsData.rowShown(row, SettingsBridge) && (row.kind !== "custom" || _custom !== null)
    // the option's current value (undefined for rows without one)
    readonly property var value: {
        void(rev)
        return shown && row.option ? SettingsBridge.value(row.option) : undefined
    }
    readonly property var choiceList: _choices()
    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }
    readonly property SettingsStyle style: SettingsStyle { theme: theme }

    readonly property real _controlWidth: VLCStyle.dp(320, VLCStyle.scale)
    readonly property real _pad: VLCStyle.dp(5, VLCStyle.scale)
    readonly property string _help: shown && row.option ? SettingsBridge.help(row.option) : ""
    readonly property var _custom: row.kind === "custom" ? _component(row.component) : null
    property Item _customItem: null
    property var _recent: null

    visible: shown
    width: parent ? parent.width : 0
    implicitHeight: shown ? Math.max(labelBox.implicitHeight, controlArea.implicitHeight) + 2 * _pad : 0
    enabled: {
        if (!row.enabledBy || !SettingsBridge.exists(row.enabledBy))
            return true
        void(rev)
        return !!SettingsBridge.value(row.enabledBy)
    }

    // A custom row (`component: "ThemeRow.qml"`, a file in rows/, served flat next to this file) declares
    // `required property var row`; optionally `property Item delegate` (set to this delegate: rev, value, style,
    // choiceList) and `readonly property bool fullRow: true` (it draws the whole row, label included, instead of
    // the 320 px control column). Its implicitHeight sets
    // the row's. A missing file only means the custom row isn't written yet: the row hides, with no warning.
    function _component(file) {
        const c = Qt.createComponent(file)
        return c.status === Component.Ready ? c : null
    }

    // numbers within float32 precision (a float option reads 0.06 back as 0.05999999865889549)
    function _same(a, b) {
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(a))
        return String(a) === String(b)
    }

    function _choices() {
        if (row.kind !== "dropdown" && row.kind !== "segments" && !(row.kind === "slider" && row.choices))
            return []
        let list = row.choices
        if (!list) {
            switch (row.choicesFrom) {
            case "languages": list = SettingsBridge.languages(); break
            case "fonts": list = SettingsBridge.fontFamilies().map((f) => ({ value: f, label: f })); break
            case "opticalDrives": list = SettingsBridge.opticalDrives().map((f) => ({ value: f, label: f })); break
            case "screens": {
                list = [{ value: -1, label: qsTr("Current screen") }]
                const screens = Qt.application.screens
                for (let i = 0; i < screens.length; ++i)
                    list.push({ value: i, label: screens[i].name })
                break
            }
            default: list = shown && row.option ? SettingsBridge.choices(row.option) : []
            }
        }
        // `extra`: a comma separated list option whose entries join the list (custom aspect and crop ratios)
        if (row.extra && SettingsBridge.exists(row.extra))
            list = list.concat(String(SettingsBridge.value(row.extra)).split(",").map((r) => r.trim())
                               .filter((r) => r.length).map((r) => ({ value: r, label: r })))
        // a value outside the list shows as itself
        if (row.kind === "dropdown" && value !== undefined && !list.some((c) => _same(c.value, value)))
            list = list.concat([{ value: value, label: String(value) }])
        return list
    }

    // A choice may carry `sets: {option: value}`, written with it and part of what makes it the shown one
    // (Zoom's Fit and 1:1 are both zoom = 1; they differ by autoscale).
    function _choiceIndex() {
        void(rev)
        for (let i = 0; i < choiceList.length; ++i) {
            const sets = choiceList[i].sets
            if (_same(choiceList[i].value, value)
                    && (!sets || Object.keys(sets).every((o) => _same(SettingsBridge.value(o), sets[o]))))
                return i
        }
        return -1
    }

    function _choose(i) {
        const c = choiceList[i]
        SettingsBridge.setValue(row.option, c.value)
        for (const o in (c.sets ?? {}))
            SettingsBridge.setValue(o, c.sets[o])
    }

    function _isOn() {
        void(rev)
        let on
        if (row.list)
            on = SettingsBridge.listHas(row.list, row.module)
        else if (row.on !== undefined)
            on = _same(value, row.on)
        else
            on = !!value
        return row.invert ? !on : on
    }

    function _setOn(on) {
        if (row.invert)
            on = !on
        if (row.list)
            SettingsBridge.setListHas(row.list, row.module, on)
        else
            SettingsBridge.setValue(row.option, on ? (row.on ?? true) : (row.off ?? false))
    }

    function _write(uiValue) {
        // config = UI x scale, without the float noise (0.7 * 1000)
        SettingsBridge.setValue(row.option, row.scale ? Math.round(uiValue * row.scale * 1e6) / 1e6 : uiValue)
    }

    function _run(action) {
        const win = root.Window.window
        switch (action) {
        case "openConfig": SettingsBridge.openConfigFolder(); break
        case "legacyPrefs": DialogsProvider.legacyPrefsDialog(); break
        case "editHotkeys": DialogsProvider.prefsDialog(5); break   // SPrefsHotkeys
        case "resetAll":
            win.ask(qsTr("Are you sure you want to reset your VLC media player preferences?"),
                    () => SettingsBridge.resetAll())
            break
        case "resetHotkeys":
            win.ask(qsTr("Reset all keyboard shortcuts to their defaults?"),
                    () => SettingsBridge.resetPrefixes(["key-", "global-key-"]))
            break
        case "clearHistory":
            // VLC.MediaLibrary only exists with a media library (the button is disabled otherwise)
            if (!_recent)
                _recent = Qt.createQmlObject("import VLC.MediaLibrary; MLRecentMediaModel { ml: MediaLib }", root)
            _recent.clearHistory()
            break
        }
    }

    Component.onCompleted: {
        if (!_custom)
            return
        _customItem = _custom.createObject(controlArea, { row: root.row })
        if ("delegate" in _customItem)
            _customItem.delegate = root
        _customItem.width = Qt.binding(() => controlArea.width)
    }

    readonly property bool _fullRow: !!_customItem && _customItem.fullRow === true

    // label + info glyph
    Row {
        id: labelBox

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: !root._fullRow
        spacing: VLCStyle.dp(10, VLCStyle.scale)
        opacity: root.enabled ? 1.0 : root.style.disabledOpacity

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - root._controlWidth - VLCStyle.dp(48, VLCStyle.scale))
            text: root.row.label
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            color: root.style.rowLabel
        }

        Image {
            id: info

            anchors.verticalCenter: parent.verticalCenter
            visible: root._help.length > 0
            width: VLCStyle.dp(18, VLCStyle.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: visible ? "qrc:///redesign/settings/info.svg" : ""
            activeFocusOnTab: visible

            Accessible.role: Accessible.StaticText
            Accessible.name: root._help

            HoverHandler { id: infoHover }

            Widgets.ToolTipExt {
                colorContext.palette: VLCStyle.palette
                visible: infoHover.hovered || info.activeFocus
                text: root._help
                width: Math.min(implicitWidth, VLCStyle.dp(360, VLCStyle.scale))
            }
        }
    }

    Item {
        id: controlArea

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root._fullRow ? root.width : root._controlWidth
        implicitHeight: root._customItem ? root._customItem.implicitHeight : (control.item ? control.item.implicitHeight : 0)
        height: implicitHeight

        Loader {
            id: control

            anchors.fill: parent
            focus: true
            active: root.shown && root.row.kind !== "custom"
            sourceComponent: {
                switch (root.row.kind) {
                case "toggle": return toggleC
                case "dropdown": return root.row.editable ? editableC : dropdownC
                case "field": case "password": case "number": return fieldC
                case "browseFile": case "browseFolder": return browseC
                case "button": case "wideButton": return buttonC
                case "slider": return sliderC
                case "segments": return segmentsC
                case "color": return colorC
                }
                return null
            }
        }
    }

    // the Figma's grey button: Browse, Open, Reset, Clear, Edit Keyboard Shortcuts
    component FaceButton: T.Button {
        id: btn

        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        opacity: enabled ? 1.0 : root.style.disabledOpacity
        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.style.face
            border.width: btn.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
        }
        contentItem: Widgets.LabelExt {
            text: btn.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            font.weight: Font.DemiBold
            color: root.style.rowLabel
        }
    }

    Component {
        id: toggleC

        FocusScope {
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
            SettingToggle {
                anchors.right: parent.right
                focus: true
                checked: root._isOn()
                onRequested: (on) => root._setOn(on)
                Accessible.name: root.row.label
            }
        }
    }

    Component {
        id: dropdownC

        SettingCombo {
            focus: true
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            textPadding: VLCStyle.dp(14, VLCStyle.scale)
            textRole: "label"
            model: root.choiceList
            currentIndex: root._choiceIndex()
            onActivated: (i) => root._choose(i)
            Accessible.name: root.row.label
        }
    }

    // a dropdown whose text can also be typed (the optical drive): written on Enter and on focus loss
    Component {
        id: editableC

        SettingCombo {
            id: combo

            focus: true
            editable: true
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            textRole: "label"
            model: root.choiceList
            currentIndex: root._choiceIndex()
            onActivated: (i) => root._choose(i)
            Accessible.name: root.row.label
            contentItem: T.TextField {
                text: combo.editText
                leftPadding: VLCStyle.dp(14, VLCStyle.scale)
                rightPadding: combo.indicator.width + VLCStyle.dp(14, VLCStyle.scale)
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root.style.value
                selectByMouse: true
                background: null
                onEditingFinished: if (text !== root.value) SettingsBridge.setValue(root.row.option, text)
            }
        }
    }

    Component {
        id: fieldC

        SettingField {
            focus: true
            suffix: root.row.suffix ?? ""
            placeholderText: root.row.placeholder ?? ""
            placeholderTextColor: root.style.placeholder
            echoMode: root.row.kind === "password" ? TextInput.Password : TextInput.Normal
            committedText: root.value === undefined ? ""
                           : root.row.kind === "number" ? String(Number((root.value / (root.row.scale || 1)).toPrecision(7))) : String(root.value)
            onCommitted: (t) => {
                if (root.row.kind !== "number")
                    SettingsBridge.setValue(root.row.option, t)
                else if (t.length && !isNaN(Number(t))) {
                    root._write(Number(t))
                    // Pitch shift: its filter is on while the pitch is not 0
                    if (root.row.list)
                        SettingsBridge.setListHas(root.row.list, root.row.module, Number(t) !== 0)
                }
            }
            Accessible.name: root.row.label
        }
    }

    Component {
        id: browseC

        FocusScope {
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            SettingField {
                id: path
                width: VLCStyle.dp(210, VLCStyle.scale)
                focus: true
                committedText: root.value === undefined ? "" : String(root.value)
                onCommitted: (t) => SettingsBridge.setValue(root.row.option, t)
                Accessible.name: root.row.label
            }
            FaceButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(100, VLCStyle.scale)
                text: qsTr("Browse")
                onClicked: {
                    const p = SettingsBridge.pickPath(path.committedText, root.row.kind === "browseFolder", !!root.row.save)
                    if (p.length)
                        SettingsBridge.setValue(root.row.option, p)
                }
            }
        }
    }

    Component {
        id: buttonC

        FocusScope {
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
            FaceButton {
                anchors.right: parent.right
                width: root.row.kind === "wideButton" ? parent.width : VLCStyle.dp(100, VLCStyle.scale)
                focus: true
                text: root.row.buttonText
                enabled: root.row.action !== "clearHistory" || MainCtx.mediaLibraryAvailable
                onClicked: root._run(root.row.action)
                Accessible.description: root.row.label
            }
        }
    }

    Component {
        id: sliderC

        // the track, then the tick labels under it (first left, last right, the others centred on their stop)
        FocusScope {
            readonly property bool stops: !!root.row.choices
            readonly property real lo: stops ? 0 : root.row.min
            readonly property real hi: stops ? root.choiceList.length - 1 : root.row.max
            readonly property real step: stops ? 1 : (root.row.step ?? 0)
            readonly property var labels: stops ? root.choiceList.map((c) => c.label) : (root.row.ticks ?? [])

            implicitHeight: VLCStyle.dp(47, VLCStyle.scale)

            SettingSlider {
                width: parent.width
                focus: true
                showHeader: false
                label: root.row.label
                from: parent.lo
                to: parent.hi
                stepSize: parent.step
                // one mark per step, unless that would be a comb
                ticks: parent.step > 0 && (parent.hi - parent.lo) / parent.step <= 40
                       ? Math.round((parent.hi - parent.lo) / parent.step) + 1 : 0
                value: {
                    const v = root.value
                    if (v === undefined)
                        return from
                    if (!parent.stops) {
                        const u = v / (root.row.scale || 1)
                        // an int option stores the scaled value rounded (128 for 50 %): sit on the step
                        return root.row.scale && step > 0 ? from + Math.round((u - from) / step) * step : u
                    }
                    // the nearest stop
                    let best = 0
                    for (let i = 1; i < root.choiceList.length; ++i)
                        if (Math.abs(root.choiceList[i].value - v) < Math.abs(root.choiceList[best].value - v))
                            best = i
                    return best
                }
                defaultValue: {
                    const d = root.row.option ? SettingsBridge.defaultValue(root.row.option) : undefined
                    return d === undefined || parent.stops ? from : d / (root.row.scale || 1)
                }
                onMoved: (v) => {
                    if (parent.stops)
                        SettingsBridge.setValue(root.row.option, root.choiceList[Math.round(v)].value)
                    else
                        root._write(v)
                }
            }

            Repeater {
                model: parent.labels
                Widgets.LabelExt {
                    required property int index
                    required property string modelData
                    readonly property int last: parent.labels.length - 1
                    y: VLCStyle.dp(28, VLCStyle.scale)
                    x: index === 0 ? 0 : index === last ? parent.width - width
                                                        : parent.width * index / last - width / 2
                    text: modelData
                    font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                    color: root.style.label
                }
            }
        }
    }

    Component {
        id: segmentsC

        SettingSegments {
            focus: true
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            model: root.choiceList.map((c) => c.label)
            currentIndex: root._choiceIndex()
            onActivated: (i) => SettingsBridge.setValue(root.row.option, root.choiceList[i].value)
        }
    }

    Component {
        id: colorC

        ColorField {
            focus: true
            colorVar: root.row.option
            // ColorField writes through Effects.setConfigValue: follow both revisions
            committedText: {
                void(Effects.revision)
                void(root.rev)
                const v = SettingsBridge.value(root.row.option)
                return "#" + Number(v ?? 0).toString(16).toUpperCase().padStart(6, "0")
            }
            Accessible.name: root.row.label
        }
    }
}
