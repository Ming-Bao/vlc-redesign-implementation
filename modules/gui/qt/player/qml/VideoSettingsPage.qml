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

// Figma video settings, 498:2965
SettingsPage {
    id: root

    // re-read a VLCVarChoiceModel's checked row when the panel opens or the outputs change
    function checkedRow(model) {
        void(Effects.revision)
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
                function rebuild() {
                    const rm = Player.rendererManager
                    renderers.clear()
                    renderers.append({ name: qsTr("Local") })
                    let sel = 0
                    for (let i = 0; i < rm.rowCount(); ++i) {
                        renderers.append({ name: rm.data(rm.index(i, 0), _roleName) })
                        if (rm.data(rm.index(i, 0), _roleSelected)) sel = i + 1
                    }
                    currentIndex = sel
                }
                onActivated: (i) => {
                    const rm = Player.rendererManager
                    if (i === 0) {
                        for (let r = 0; r < rm.rowCount(); ++r)
                            if (rm.data(rm.index(r, 0), _roleSelected)) rm.setData(rm.index(r, 0), false, _roleSelected)
                    } else
                        rm.setData(rm.index(i - 1, 0), true, _roleSelected)
                }
                onPressedChanged: if (pressed) Player.rendererManager.StartScan()
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
}
