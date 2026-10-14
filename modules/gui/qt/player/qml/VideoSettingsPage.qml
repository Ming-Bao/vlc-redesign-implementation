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
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// Figma video settings, 498:2965
SettingsPage {
    id: root

    // what the preset button's reset writes back to the defaults, and the filters it switches off
    readonly property var resetNames: ["hue", "brightness", "contrast", "saturation", "gamma", "sharpen-sigma", "gradfun-radius", "grain-variance", "extract-component", "colorthres-color", "colorthres-saturationthres", "colorthres-similaritythres", "gradient-mode", "gradient-color", "gradient-cartoon", "sepia-intensity", "preferred-resolution"]
    readonly property var resetModules: ["adjust", "sharpen", "gradfun", "grain", "extract", "colorthres", "invert", "posterize", "gradient", "sepia", "transform"]

    // re-read a VLCVarChoiceModel's checked row when the panel opens or the outputs change
    // bumped when a checkable model changes under us (hotkeys, menus), which Effects.revision does not cover
    property int _modelTick: 0
    Connections { target: Player.zoom; function onDataChanged() { root._modelTick++ } function onModelReset() { root._modelTick++ } }
    Connections { target: Player.aspectRatio; function onDataChanged() { root._modelTick++ } function onModelReset() { root._modelTick++ } }
    Connections { target: Player.crop; function onDataChanged() { root._modelTick++ } function onModelReset() { root._modelTick++ } }

    // [label, var, module, from, to, step, default, ticks, display(v) -> string]
    readonly property var essential: [
        [qsTr("Hue"),         "hue",             "adjust",  -180, 180, 1,    0,    0, (v) => v.toFixed(0) + "\u00B0"],
        [qsTr("Brightness"),  "brightness",      "adjust",  0,    2,   0.01, 1,    0, (v) => v.toFixed(2)],
        [qsTr("Contrast"),    "contrast",        "adjust",  0,    2,   0.01, 1,    0, (v) => v.toFixed(2)],
        [qsTr("Saturation"),  "saturation",      "adjust",  0,    3,   0.01, 1,    3, (v) => v.toFixed(2)],
        [qsTr("Gamma"),       "gamma",           "adjust",  0.01, 10,  0.01, 1,    10, (v) => v.toFixed(2)],
        [qsTr("Sharpen Sigma"), "sharpen-sigma", "sharpen", 0,    2,   0.01, 0.05, 5, (v) => v.toFixed(2)],
        [qsTr("Banding Removal Radius"), "gradfun-radius", "gradfun", 4, 32, 1, 16, 8, (v) => v.toFixed(0)],
        [qsTr("Film Grain Variance"), "grain-variance", "grain", 0, 10, 0.1, 2, 10, (v) => v.toFixed(1)],
    ]

    // the current value of a spec row; a var that does not exist yet (filter off) counts as its default
    function specValue(spec) {
        const v = Effects.value(spec[1])
        return (v === undefined || v === null || v === "" || isNaN(Number(v))) ? spec[6] : Number(v)
    }

    // a value-driven filter is on while any of its values differs from its default
    function setDriven(specs, idx, v) {
        const s = specs[idx]
        Effects.setValue(s[1], v)
        const on = specs.some((o) => o[2] === s[2] && Math.abs(specValue(o) - o[6]) > o[5] / 2)
        if (on !== Effects.filterEnabled(s[2]))
            Effects.setFilterEnabled(s[2], on)
    }

    component CropField: SettingField {
        required property string side
        required property string title
        required property bool linked
        Layout.fillWidth: true
        implicitWidth: VLCStyle.dp(141, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(33, VLCStyle.scale)
        leftPadding: VLCStyle.dp(72, VLCStyle.scale)
        suffix: qsTr(" px")
        validator: IntValidator { bottom: 0; top: 4096 }
        committedText: { void(Effects.revision); return String(Effects.voutCrop(side)) }
        onCommitted: (t) => {
            const px = parseInt(t) || 0
            Effects.setVoutCrop(side, px)
            if (linked)
                Effects.setVoutCrop({ top: "bottom", bottom: "top", left: "right", right: "left" }[side], px)
        }
        Widgets.LabelExt {
            x: VLCStyle.dp(12, VLCStyle.scale); anchors.verticalCenter: parent.verticalCenter
            text: parent.title; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale); color: parent._s.label
        }
    }

    component Divider: Rectangle {
        readonly property ColorContext colorContext: ColorContext { id: dTheme; colorSet: ColorContext.Window }
        readonly property SettingsStyle _s: SettingsStyle { theme: dTheme }
        Layout.fillWidth: true
        implicitHeight: 1
        color: _s.divider
    }

    component ColorRow: SettingRow {
        required property string module
        required property string colorVar
        ColorField { implicitWidth: VLCStyle.dp(116, VLCStyle.scale); colorVar: parent.colorVar; live: true }
        SettingToggle {
            checked: { void(Effects.revision); return Effects.filterEnabled(parent.module) }
            onRequested: (on) => Effects.setFilterEnabled(parent.module, on)
        }
    }

    component ModuleToggle: SettingRow {
        required property string module
        SettingToggle {
            checked: { void(Effects.revision); return Effects.filterEnabled(parent.module) }
            onRequested: (on) => Effects.setFilterEnabled(parent.module, on)
        }
    }

    function checkedRow(model) {
        void(Effects.revision)
        void(_modelTick)
        for (let i = 0; i < model.rowCount(); ++i)
            if (model.data(model.index(i, 0), Qt.CheckStateRole))
                return i
        return 0
    }

    SettingSection {
        title: qsTr("Defaults")
        divider: false

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            SettingRow { label: qsTr("Flip") }
            SettingSegments {
                model: [qsTr("None"), qsTr("Horizontal"), qsTr("Vertical")]
                currentIndex: { void(Effects.revision); return Effects.transformFlip() }
                onActivated: (i) => Effects.setTransform(i, Effects.transformRotation())
            }
        }

        SettingRow {
            label: qsTr("Rotate")
            SettingField {
                suffix: qsTr(" deg")
                validator: IntValidator { bottom: -360; top: 360 }
                committedText: { void(Effects.revision); return String(Effects.transformRotation()) }
                onCommitted: (t) => Effects.setTransform(Effects.transformFlip(), parseInt(t) || 0)
                // a step changes the live value, so the edit text must follow it or the focus-out would
                // commit the stale text (several flip/rotation pairs are one transform and read back canonically)
                function _step(delta) {
                    Effects.setTransform(Effects.transformFlip(), Effects.transformRotation() + delta)
                    text = committedText
                    selectAll()
                }
                Keys.onUpPressed: _step(90)
                Keys.onDownPressed: _step(-90)
            }
        }

        SettingRow {
            label: qsTr("Zoom")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.zoom; textRole: "display"
                currentIndex: root.checkedRow(Player.zoom)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Resolution")
            SettingCombo {
                readonly property var values: [-1, 1080, 720, 576, 360, 240]
                model: [qsTr("Best Available"), qsTr("Full HD (1080p)"), qsTr("HD (720p)"),
                        qsTr("Standard (576p)"), qsTr("Low (360p)"), qsTr("Very Low (240p)")]
                currentIndex: { void(Effects.revision); return Math.max(0, values.indexOf(Number(Effects.configValue("preferred-resolution")))) }
                onActivated: (i) => Effects.setConfigValue("preferred-resolution", values[i])
            }
        }

        SettingRow {
            label: qsTr("Aspect Ratio")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.aspectRatio; textRole: "display"
                currentIndex: root.checkedRow(Player.aspectRatio)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Crop")
            SettingCombo {
                enabled: Effects.hasVideo
                model: Player.crop; textRole: "display"
                currentIndex: root.checkedRow(Player.crop)
                onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
            }
        }

        SettingRow {
            label: qsTr("Render")
            SettingCombo {
                id: renderCombo
                // row 0 is this device; the renderer manager's rows follow
                model: ListModel { id: renderers }
                textRole: "name"
                // RendererManager::Roles: NAME = Qt::UserRole (256) … SELECTED = 262
                readonly property int _roleName: 256
                readonly property int _roleSelected: 262
                // updates the list in place: clearing it would reset an open popup
                function rebuild() {
                    const rm = Player.rendererManager
                    const n = rm ? rm.rowCount() : 0
                    if (renderers.count === 0)
                        renderers.append({ name: qsTr("Local") })
                    let sel = 0
                    for (let i = 0; i < n; ++i) {
                        const name = rm.data(rm.index(i, 0), _roleName)
                        if (i + 1 < renderers.count) renderers.set(i + 1, { name: name })
                        else renderers.append({ name: name })
                        if (rm.data(rm.index(i, 0), _roleSelected)) sel = i + 1
                    }
                    while (renderers.count > n + 1)
                        renderers.remove(renderers.count - 1)
                    currentIndex = sel
                }
                onActivated: (i) => {
                    const rm = Player.rendererManager
                    if (!rm) return
                    if (i === 0) {
                        for (let r = 0; r < rm.rowCount(); ++r)
                            if (rm.data(rm.index(r, 0), _roleSelected)) rm.setData(rm.index(r, 0), false, _roleSelected)
                    } else
                        rm.setData(rm.index(i - 1, 0), true, _roleSelected)
                }
                // scan when the popup opens (a press that closes it must not restart the scan)
                Connections {
                    target: renderCombo.popup
                    function onOpened() { if (Player.rendererManager) Player.rendererManager.StartScan() }
                }
                Connections {
                    target: Player.rendererManager
                    function onRowsInserted() { renderCombo.rebuild() }
                    function onRowsRemoved() { renderCombo.rebuild() }
                    function onDataChanged() { renderCombo.rebuild() }
                }
                Component.onCompleted: rebuild()
            }
        }
    }

    SettingSection {
        title: qsTr("Filters")

        SettingRow { label: qsTr("Essential") }
        EffectAccordion {
            Repeater {
                model: root.essential
                SettingSlider {
                    required property var modelData
                    required property int index
                    label: modelData[0]
                    valueText: ""
                    Accessible.description: modelData[8](value)
                    from: modelData[3]; to: modelData[4]; stepSize: modelData[5]
                    defaultValue: modelData[6]; ticks: modelData[7]
                    value: { void(Effects.revision); return root.specValue(modelData) }
                    onMoved: (v) => root.setDriven(root.essential, index, v)
                }
            }
        }
    }

    SettingSection {
        title: ""   // Figma: sub-blocks are separated by a divider and a 14 px label, not a new title
        SettingRow { label: qsTr("Crop") }
        EffectAccordion {
            enabled: Effects.hasVideo
            GridLayout {
                id: cropGrid
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.dp(6, VLCStyle.scale)
                columns: 3
                columnSpacing: VLCStyle.dp(8, VLCStyle.scale)
                rowSpacing: VLCStyle.dp(16, VLCStyle.scale)
                property bool linkV: false
                property bool linkH: false

                CropField { side: "top"; title: qsTr("Top"); linked: cropGrid.linkV }
                CropField { side: "bottom"; title: qsTr("Bottom"); linked: cropGrid.linkV }
                Widgets.IconToolButton {
                    text: VLCIcons.link
                    checked: cropGrid.linkV
                    onClicked: {
                        cropGrid.linkV = !cropGrid.linkV
                        if (cropGrid.linkV) Effects.setVoutCrop("bottom", Effects.voutCrop("top"))
                    }
                    description: qsTr("Link top and bottom")
                }
                CropField { side: "left"; title: qsTr("Left"); linked: cropGrid.linkH }
                CropField { side: "right"; title: qsTr("Right"); linked: cropGrid.linkH }
                Widgets.IconToolButton {
                    text: VLCIcons.link
                    checked: cropGrid.linkH
                    onClicked: {
                        cropGrid.linkH = !cropGrid.linkH
                        if (cropGrid.linkH) Effects.setVoutCrop("right", Effects.voutCrop("left"))
                    }
                    description: qsTr("Link left and right")
                }
            }
        }
    }

    SettingSection {
        title: ""
        SettingRow { label: qsTr("Colors") }
        EffectAccordion {
            ColorRow { label: qsTr("Color Extraction"); module: "extract"; colorVar: "extract-component" }
            Divider { }
            ColorRow { label: qsTr("Color Threshold"); module: "colorthres"; colorVar: "colorthres-color" }
            SettingSlider {
                label: qsTr("Saturation"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 20
                value: { void(Effects.revision); return Number(Effects.value("colorthres-saturationthres")) }
                onMoved: (v) => Effects.setValue("colorthres-saturationthres", Math.round(v))
            }
            SettingSlider {
                label: qsTr("Similarity"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 15
                value: { void(Effects.revision); return Number(Effects.value("colorthres-similaritythres")) }
                onMoved: (v) => Effects.setValue("colorthres-similaritythres", Math.round(v))
            }
            Divider { }
            ModuleToggle { label: qsTr("Negate Colors"); module: "invert" }
            Divider { }
            ModuleToggle { label: qsTr("Posterize"); module: "posterize" }
            Divider { }
            ModuleToggle { label: qsTr("Gradient"); module: "gradient" }
            SettingCombo {
                fullWidth: true
                readonly property var modes: ["gradient", "edge", "hough"]
                model: [qsTr("Gradient"), qsTr("Edge"), qsTr("Hough")]
                currentIndex: { void(Effects.revision); return Math.max(0, modes.indexOf(String(Effects.value("gradient-mode")))) }
                onActivated: (i) => Effects.setValue("gradient-mode", modes[i])
            }
            SettingRow {
                label: qsTr("Color")
                SettingToggle {
                    // gradient-type is obsolete since 4.0.0: the option is the boolean gradient-color
                    checked: { void(Effects.revision); return Boolean(Effects.value("gradient-color")) }
                    onRequested: (on) => Effects.setValue("gradient-color", on)
                }
            }
            SettingRow {
                label: qsTr("Cartoon")
                SettingToggle {
                    checked: { void(Effects.revision); return Boolean(Effects.value("gradient-cartoon")) }
                    onRequested: (on) => Effects.setValue("gradient-cartoon", on)
                }
            }
            Divider { }
            SettingSlider {
                label: qsTr("Sepia Intensity"); valueText: ""
                from: 0; to: 255; stepSize: 1; defaultValue: 0; ticks: 3
                value: { void(Effects.revision); return Effects.filterEnabled("sepia") ? Number(Effects.value("sepia-intensity")) : 0 }
                onMoved: (v) => {
                    Effects.setValue("sepia-intensity", Math.round(v))
                    if ((v > 0) !== Effects.filterEnabled("sepia")) Effects.setFilterEnabled("sepia", v > 0)
                }
            }
        }
    }
}
