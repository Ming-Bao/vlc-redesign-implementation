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

    SettingSection {
        title: qsTr("Defaults")
        divider: false

        SettingRow {
            label: qsTr("Audio Track")
            SettingField {
                validator: IntValidator { bottom: -1; top: 99 }
                committedText: { void(Effects.revision); const n = Number(Effects.configValue("audio-track")); return n < 0 ? qsTr("Auto") : String(n + 1) }
                onCommitted: (t) => Effects.setConfigValue("audio-track", t === "" || t === qsTr("Auto") ? -1 : Math.max(0, parseInt(t) - 1))
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
            enabled: model.rowCount() > 0
            displayText: enabled ? currentText : qsTr("Unavailable")
            model: Player.audioStereoMode; textRole: "display"
            currentIndex: {
                void(Effects.revision)
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
