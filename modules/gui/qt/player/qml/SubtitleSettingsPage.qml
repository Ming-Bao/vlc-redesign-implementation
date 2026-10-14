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
import VLC.Widgets as Widgets

// Figma subtitle settings, 763:1986
SettingsPage {
    id: root

    // what the preset button's reset writes back to the defaults, and the filters it switches off
    readonly property var resetNames: ["sub-track", "sub-language", "subsdelay-factor", "freetype-font", "freetype-color", "freetype-outline-color", "sub-margin", "freetype-outline-thickness", "freetype-background-opacity", "sub-text-scale"]
    readonly property var resetModules: ["subsdelay"]

    function resetToDefaults() {
        Effects.resetToDefaults(resetNames, resetModules)
        // the text scale is applied live as well
        Effects.setSubtitleTextScale(100)
    }

    // a small hint under a row (settings that the text renderer only reads when it opens)
    component Note: Widgets.LabelExt {
        readonly property ColorContext colorContext: ColorContext { id: noteTheme; colorSet: ColorContext.Window }
        readonly property SettingsStyle _s: SettingsStyle { theme: noteTheme }
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(4, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
        color: _s.label
    }

    // index of the stop nearest to value
    function nearestStop(stops, value) {
        let best = 0
        for (let i = 1; i < stops.length; ++i) if (Math.abs(stops[i] - value) < Math.abs(stops[best] - value)) best = i
        return best
    }

    // the duration factor lives in the subsdelay filter: on while the factor is above zero
    function setDuration(v) {
        Effects.setValue("subsdelay-factor", v)
        if ((v > 0) !== Effects.filterEnabled("subsdelay")) Effects.setFilterEnabled("subsdelay", v > 0)
    }

    SettingSection {
        title: qsTr("Defaults")
        divider: false
        SettingRow {
            label: qsTr("Subtitle Track")
            TrackField { configName: "sub-track" }
        }
        SettingRow {
            label: qsTr("Subtitle Language")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("sub-language")) }
                onCommitted: (t) => Effects.setConfigValue("sub-language", t)
            }
        }
    }

    SettingSection {
        title: qsTr("Synchronization")
        SettingRow {
            label: qsTr("Subtitle Track Delay")
            SettingField {
                suffix: qsTr(" s")
                validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }
                committedText: (Player.subtitleDelayMS / 1000).toFixed(3)
                onCommitted: (t) => { const s = parseFloat(t.replace(",", ".")); if (!isNaN(s)) Player.subtitleDelayMS = Math.round(Math.max(-10, Math.min(10, s)) * 1000) }
            }
        }
        DelaySlider { valueMs: Player.subtitleDelayMS; onMovedMs: (ms) => Player.subtitleDelayMS = ms }

        SettingRow {
            label: qsTr("Subtitle Speed")
            SettingField {
                suffix: qsTr(" fps")
                validator: RegularExpressionValidator { regularExpression: /[0-9]*[.,]?[0-9]*/ }
                committedText: Player.subtitleFPS.toFixed(3)
                onCommitted: (t) => { const v = parseFloat(t.replace(",", ".")); if (!isNaN(v)) Player.subtitleFPS = Math.max(1, Math.min(100, v)) }
            }
        }
        SettingSlider {
            showHeader: false
            from: 1; to: 100; stepSize: 0.2; defaultValue: 1
            value: Player.subtitleFPS
            onMoved: (v) => Player.subtitleFPS = v
        }

        SettingRow {
            label: qsTr("Subtitle Duration Factor")
            SettingField {
                validator: RegularExpressionValidator { regularExpression: /[0-9]*[.,]?[0-9]*/ }
                committedText: { void(Effects.revision); return Effects.filterEnabled("subsdelay") ? Number(Effects.value("subsdelay-factor")).toFixed(3) : "0.000" }
                onCommitted: (t) => { const v = parseFloat(t.replace(",", ".")); if (!isNaN(v)) root.setDuration(Math.max(0, Math.min(20, v))) }
            }
        }
        SettingSlider {
            showHeader: false
            from: 0; to: 20; stepSize: 0.2; defaultValue: 0
            value: { void(Effects.revision); return Effects.filterEnabled("subsdelay") ? Number(Effects.value("subsdelay-factor")) : 0 }
            onMoved: (v) => root.setDuration(v)
        }
    }

    SettingSection {
        title: qsTr("Appearance")

        SettingRow {
            label: qsTr("Subtitle Font")
            SettingField {
                committedText: { void(Effects.revision); return String(Effects.configValue("freetype-font")) }
                onCommitted: (t) => Effects.setConfigValue("freetype-font", t)
            }
        }
        Note { text: qsTr("Applies to the next video") }
        SettingRow { label: qsTr("Text Color"); ColorField { colorVar: "freetype-color" } }
        SettingRow { label: qsTr("Outline Color"); ColorField { colorVar: "freetype-outline-color" } }
        Note { text: qsTr("Applies to the next video") }
        SettingRow {
            label: qsTr("Subtitle Offset")
            SettingField {
                suffix: qsTr(" px")
                validator: IntValidator { bottom: 0; top: 2000 }
                committedText: { void(Effects.revision); return String(Effects.value("sub-margin")) }
                onCommitted: (t) => { const n = parseInt(t); if (!isNaN(n)) Effects.setValue("sub-margin", Math.max(0, Math.min(2000, n))) }   // NaN reverts
            }
        }

        SettingSlider {
            readonly property var stops: [50, 75, 100, 125, 150, 200]
            readonly property var names: [qsTr("Smaller"), qsTr("Small"), qsTr("Auto"), qsTr("Large"), qsTr("Larger"), qsTr("Largest")]
            label: qsTr("Font Size")
            from: 0; to: 5; stepSize: 1; defaultValue: 2; ticks: 6
            value: { void(Effects.revision); return root.nearestStop(stops, Effects.subtitleTextScale()) }
            valueText: names[Math.round(value)]
            onMoved: (v) => Effects.setSubtitleTextScale(stops[Math.round(v)])
        }
        SettingSlider {
            readonly property var stops: [0, 2, 4, 6]
            readonly property var names: [qsTr("None"), qsTr("Thin"), qsTr("Normal"), qsTr("Thick")]
            label: qsTr("Outline Thickness")
            from: 0; to: 3; stepSize: 1; defaultValue: 2; ticks: 4
            value: { void(Effects.revision); return root.nearestStop(stops, Number(Effects.configValue("freetype-outline-thickness"))) }
            valueText: names[Math.round(value)]
            onMoved: (v) => Effects.setConfigValue("freetype-outline-thickness", stops[Math.round(v)])
        }
        SettingSlider {
            label: qsTr("Background Opacity")
            from: 0; to: 100; stepSize: 10; defaultValue: 0; ticks: 11
            value: { void(Effects.revision); return Math.round(Number(Effects.configValue("freetype-background-opacity")) / 2.55) }
            valueText: qsTr("%1 %").arg(Math.round(value))
            onMoved: (v) => Effects.setConfigValue("freetype-background-opacity", Math.round(v * 2.55))
        }
    }
}
