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

    // the panel reopens on the last tab
    property int _lastTab: 0

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    readonly property var _parentItem: ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null)) ? rootPlayer
                                                                                                       : g_mainDisplay

    enabled: panelLoader.status === Loader.Ready

    // while the panel is open it is modal: a click on this button only closes it
    onClicked: panelLoader.item.open()

    Loader {
        id: panelLoader

        sourceComponent: PlaybackPanel {
            id: panel

            parent: extdSettingsBtn._parentItem

            currentTab: extdSettingsBtn._lastTab
            onCurrentTabChanged: extdSettingsBtn._lastTab = currentTab

            x: parent.width - width - VLCStyle.dp(20, VLCStyle.scale)
            y: parent.positionSliderY - height - VLCStyle.dp(20, VLCStyle.scale)
            // 20 dp above the bar, clear of the top bar
            maximumHeight: parent.positionSliderY - VLCStyle.dp(80, VLCStyle.scale)
            z: 1

            colorContext.palette: extdSettingsBtn.colorContext.palette

            onOpened: {
                extdSettingsBtn.requestLockUnlockAutoHide(true)
                extdSettingsBtn.menuOpened(panel)
            }

            onClosed: {
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
