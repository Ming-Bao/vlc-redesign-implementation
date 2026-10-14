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
import VLC.Player

// Figma audio settings, 536:1087
SettingsPage {
    id: root

    // the stereo-mode model changes under us (rows arrive with the audio output, hotkeys flip the checked row)
    property int _modelTick: 0
    Connections {
        target: Player.audioStereoMode
        function onRowsInserted() { root._modelTick++ }
        function onRowsRemoved() { root._modelTick++ }
        function onModelReset() { root._modelTick++ }
        function onDataChanged() { root._modelTick++ }
    }

    component BandSlider: ColumnLayout {
        id: band
        property string label
        property real value
        property real defaultValue: 0
        signal moved(real v)
        Layout.fillWidth: true
        spacing: VLCStyle.dp(5, VLCStyle.scale)
        SettingRow {
            label: band.label
            SettingField {
                implicitWidth: VLCStyle.dp(140, VLCStyle.scale)
                suffix: " dB"
                validator: DoubleValidator { decimals: 1 }
                committedText: band.value.toFixed(1)
                onCommitted: (t) => { const v = parseFloat(t); if (!isNaN(v)) band.moved(Math.max(-20, Math.min(20, v))) }
            }
        }
        SettingSlider {
            showHeader: false
            from: -20; to: 20; stepSize: 0.1; defaultValue: band.defaultValue
            value: band.value
            onMoved: (v) => band.moved(v)
        }
    }

    // [label, var, from, to, step, default, ticks, scale, unit, decimals]
    component FilterBlock: SettingSection {
        id: block
        required property string blockTitle
        required property string module
        required property var specs
        title: ""
        SettingRow {
            label: block.blockTitle
            SettingToggle {
                checked: { void(Effects.revision); return Effects.filterEnabled(block.module) }
                onRequested: (on) => Effects.setFilterEnabled(block.module, on)
            }
        }
        EffectAccordion {
            Repeater {
                model: block.specs
                SettingSlider {
                    required property var modelData
                    readonly property real k: modelData[7]
                    label: modelData[0]
                    from: modelData[2] * k; to: modelData[3] * k; stepSize: modelData[4] * k
                    defaultValue: modelData[5] * k; ticks: modelData[6]
                    value: { void(Effects.revision); return Number(Effects.value(modelData[1])) * k }
                    valueText: value.toFixed(modelData[9]) + modelData[8]
                    onMoved: (v) => Effects.setValue(modelData[1], v / k)
                }
            }
        }
    }

    SettingSection {
        title: qsTr("Defaults")
        divider: false

        SettingRow {
            label: qsTr("Audio Track")
            SettingField {
                validator: IntValidator { bottom: -1; top: 99 }
                committedText: { void(Effects.revision); const n = Number(Effects.configValue("audio-track")); return n < 0 ? qsTr("Auto") : String(n + 1) }
                onCommitted: (t) => {
                    if (t === "" || t === "-1" || t === qsTr("Auto")) { Effects.setConfigValue("audio-track", -1); return }
                    const n = parseInt(t)
                    if (!isNaN(n)) Effects.setConfigValue("audio-track", Math.max(0, n - 1))   // NaN (e.g. a lone "-") reverts
                }
            }
        }
        SettingRow {
            label: qsTr("Audio Language")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("audio-language")) }
                onCommitted: (t) => Effects.setConfigValue("audio-language", t)
            }
        }
        SettingRow { label: qsTr("Stereo Mode") }
        SettingCombo {
            fullWidth: true
            enabled: { void(root._modelTick); return model.rowCount() > 0 }
            displayText: enabled ? currentText : qsTr("Unavailable")
            model: Player.audioStereoMode; textRole: "display"
            currentIndex: {
                void(Effects.revision); void(root._modelTick)
                for (let i = 0; i < model.rowCount(); ++i)
                    if (model.data(model.index(i, 0), Qt.CheckStateRole)) return i
                return 0
            }
            onActivated: (i) => model.setData(model.index(i, 0), true, Qt.CheckStateRole)
        }
    }

    SettingSection {
        title: qsTr("Synchronization")
        SettingRow {
            label: qsTr("Audio Track Delay")
            SettingField {
                id: delayField
                suffix: " s"
                validator: DoubleValidator { notation: DoubleValidator.StandardNotation; decimals: 3 }
                committedText: (Player.audioDelayMS / 1000).toFixed(3)
                onCommitted: (t) => {
                    const s = parseFloat(t)
                    if (!isNaN(s)) Player.audioDelayMS = Math.round(Math.max(-10, Math.min(10, s)) * 1000)
                }
            }
        }
        DelaySlider { valueMs: Player.audioDelayMS; onMovedMs: (ms) => Player.audioDelayMS = ms }
    }

    SettingSection {
        title: qsTr("Filters")

        SettingRow { label: qsTr("Equalizer") }
        SettingCombo {
            fullWidth: true
            // 0 = None (filter off), 1..18 = presets, last = Custom (the bands match no preset)
            model: [qsTr("None")].concat(Effects.equalizerPresets).concat([qsTr("Custom")])
            currentIndex: {
                void(Effects.revision)
                if (!Effects.filterEnabled("equalizer")) return 0
                const p = Effects.equalizerPresetIndex()
                return p < 0 ? model.length - 1 : p + 1
            }
            onActivated: (i) => {
                if (i === 0) { Effects.setFilterEnabled("equalizer", false); return }
                if (i <= Effects.equalizerPresets.length) Effects.applyEqualizerPreset(i - 1)
                if (!Effects.filterEnabled("equalizer")) Effects.setFilterEnabled("equalizer", true)
            }
        }
        EffectAccordion {
            BandSlider {
                label: qsTr("Preamp")
                defaultValue: 12   // module default of equalizer-preamp
                value: { void(Effects.revision); return Number(Effects.value("equalizer-preamp")) }
                onMoved: (v) => Effects.setValue("equalizer-preamp", v)
            }
            Repeater {
                model: { void(Effects.revision); return Effects.value("equalizer-vlcfreqs")
                    ? [qsTr("60 Hz"), qsTr("170 Hz"), qsTr("310 Hz"), qsTr("600 Hz"), qsTr("1 KHz"),
                       qsTr("3 KHz"), qsTr("6 KHz"), qsTr("12 KHz"), qsTr("14 KHz"), qsTr("16 KHz")]
                    : [qsTr("31 Hz"), qsTr("63 Hz"), qsTr("125 Hz"), qsTr("250 Hz"), qsTr("500 Hz"),
                       qsTr("1 KHz"), qsTr("2 KHz"), qsTr("4 KHz"), qsTr("8 KHz"), qsTr("16 KHz")] }
                BandSlider {
                    required property int index
                    required property string modelData
                    label: modelData
                    value: { void(Effects.revision); return Effects.equalizerBand(index) }
                    onMoved: (v) => {
                        Effects.setEqualizerBand(index, v)
                        if (!Effects.filterEnabled("equalizer")) Effects.setFilterEnabled("equalizer", true)
                    }
                }
            }
        }
        SettingRow {
            label: qsTr("2 Pass")
            SettingToggle {
                checked: { void(Effects.revision); return Boolean(Effects.value("equalizer-2pass")) }
                onRequested: (on) => Effects.setValue("equalizer-2pass", on)
            }
        }
    }

    FilterBlock {
        blockTitle: qsTr("Compressor"); module: "compressor"
        specs: [
            [qsTr("FM5 / Peak"),  "compressor-rms-peak",    0,   1,   0.01, 0.2, 0, 1, "",        1],
            [qsTr("Attack"),      "compressor-attack",      1.5, 400, 0.5,  25,  0, 1, qsTr(" ms"), 1],
            [qsTr("Release"),     "compressor-release",     2,   800, 1,    100, 0, 1, qsTr(" ms"), 1],
            [qsTr("Threshold"),   "compressor-threshold",   -30, 0,   0.5,  -11, 0, 1, qsTr(" dB"), 1],
            [qsTr("Ratio"),       "compressor-ratio",       1,   20,  0.1,  4,   0, 1, " : 1",    1],
            [qsTr("Knee Radius"), "compressor-knee",        1,   10,  0.1,  5,   0, 1, qsTr(" dB"), 1],
            [qsTr("Makeup Gain"), "compressor-makeup-gain", 0,   24,  0.1,  7,   0, 1, qsTr(" dB"), 1],
        ]
    }
    FilterBlock {
        blockTitle: qsTr("Spatializer"); module: "spatializer"
        specs: [
            [qsTr("Size"),  "spatializer-roomsize", 0, 1.1, 0.01, 0.85, 12, 10, "", 1],
            [qsTr("Width"), "spatializer-width",    0, 1,   0.01, 1,    11, 10, "", 1],
            [qsTr("Wet"),   "spatializer-wet",      0, 1,   0.01, 0.4,  11, 10, "", 1],
            [qsTr("Dry"),   "spatializer-dry",      0, 1,   0.01, 0.5,  11, 10, "", 1],
            [qsTr("Damp"),  "spatializer-damp",     0, 1,   0.01, 0.5,  11, 10, "", 1],
        ]
    }
    FilterBlock {
        blockTitle: qsTr("Stereo Widener"); module: "stereo_widen"
        specs: [
            [qsTr("Delay Time"),    "stereowiden-delay",     1, 100, 1,    20,  0,  1, qsTr(" ms"), 1],
            [qsTr("Feedback Gain"), "stereowiden-feedback",  0, 0.9, 0.01, 0.3, 10, 1, " %",       1],
            [qsTr("Crossfeed"),     "stereowiden-crossfeed", 0, 0.8, 0.01, 0.3, 9,  1, " %",       1],
            [qsTr("Dry Mix"),       "stereowiden-dry-mix",   0, 1,   0.01, 0.8, 11, 1, " %",       1],
        ]
    }

    SettingSection {
        title: ""
        SettingSlider {
            label: qsTr("Adjust Pitch")
            valueText: qsTr("%1 semitones").arg(value.toFixed(1))
            from: -12; to: 12; stepSize: 0.25; defaultValue: 0; ticks: 3
            value: { void(Effects.revision); return Effects.filterEnabled("scaletempo_pitch") ? Number(Effects.value("pitch-shift")) : 0 }
            onMoved: (v) => {
                Effects.setValue("pitch-shift", v)
                if ((v !== 0) !== Effects.filterEnabled("scaletempo_pitch"))
                    Effects.setFilterEnabled("scaletempo_pitch", v !== 0)
            }
        }
    }
}
