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
import VLC.Style

T.TextField {
    id: root
    property string suffix: ""
    property string committedText: ""     // owner binds the real value here
    signal committed(string text)

    readonly property ColorContext colorContext: ColorContext { id: theme; colorSet: ColorContext.TextField; focused: root.activeFocus }
    readonly property SettingsStyle _s: SettingsStyle { theme: theme }

    implicitWidth: VLCStyle.dp(140, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
    leftPadding: VLCStyle.dp(12, VLCStyle.scale)
    rightPadding: VLCStyle.dp(18, VLCStyle.scale)
    verticalAlignment: TextInput.AlignVCenter
    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    color: _s.value
    selectByMouse: true
    // shows the live value until edited; editing breaks the binding, commit or Escape restores it
    text: committedText + suffix

    onActiveFocusChanged: if (activeFocus) { text = committedText; selectAll() } else _commit()
    onAccepted: focus = false            // focus-out commits
    Keys.onEscapePressed: (ev) => { _restore(); focus = false; ev.accepted = true }

    function _restore() { text = Qt.binding(() => committedText + suffix) }
    function _commit() {
        const t = (suffix.length ? text.replace(suffix, "") : text).trim()
        _restore()
        if (t !== committedText) committed(t)
    }

    background: Rectangle {
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root._s.field
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: root.activeFocus ? theme.visualFocus : root._s.face
    }
}
