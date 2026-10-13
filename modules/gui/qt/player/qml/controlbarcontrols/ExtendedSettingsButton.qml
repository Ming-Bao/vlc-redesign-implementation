/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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


import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: extdSettingsBtn

    text: VLCIcons.effect_filter

    description: qsTr("Extended settings")

    AccessibleCompat.id: "extendedSettingsButton"

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    readonly property var _parentItem: ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null)) ? rootPlayer
                                                                                                       : g_mainDisplay

    enabled: panelLoader.status === Loader.Ready

    // a press on this button while the panel is open closes it (outside press) just before the
    // button sees that press; the click that follows must not reopen it
    property double _closedAt: 0
    property bool _reopenBlocked: false

    onPressed: _reopenBlocked = (Date.now() - _closedAt) < 100
    onClicked: {
        if (!_reopenBlocked)
            panelLoader.item.open()
    }

    Loader {
        id: panelLoader

        sourceComponent: PlaybackPanel {
            id: panel

            parent: extdSettingsBtn._parentItem

            x: parent.width - width - VLCStyle.dp(20, VLCStyle.scale)
            y: parent.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
            z: 1

            colorContext.palette: extdSettingsBtn.colorContext.palette

            onOpened: {
                extdSettingsBtn.requestLockUnlockAutoHide(true)
                extdSettingsBtn.menuOpened(panel)
            }

            onClosed: {
                extdSettingsBtn._closedAt = Date.now()
                extdSettingsBtn.requestLockUnlockAutoHide(false)
                extdSettingsBtn.forceActiveFocus()
                extdSettingsBtn.menuOpened(null)
            }
        }
    }

    function forceUnlock() {
        if (panelLoader && panelLoader.item)
            panelLoader.item.close()
    }
}
