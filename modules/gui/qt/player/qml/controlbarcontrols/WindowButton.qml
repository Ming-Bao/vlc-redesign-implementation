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
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// a client side decoration button (CSDButton.Minimize, MaximizeRestore or Close), hidden without CSD
Item {
    id: root

    property int action: CSDButton.Close
    property bool paintOnly: false

    // the model's button, which does the platform's work
    readonly property var _button: MainCtx.csdButtonModel.windowCSDButtons.find(b => b.type === action)
    readonly property bool _shown: paintOnly || MainCtx.clientSideDecoration
    readonly property bool useWinIcons: ((MainCtx.osName === MainCtx.Windows) && (MainCtx.osVersion >= 10))

    enabled: _shown && !paintOnly

    implicitWidth: _shown ? VLCStyle.dp(40, VLCStyle.scale) : 0
    implicitHeight: VLCStyle.globalToolbar_height

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    function _updateRect() {
        if (!_button)
            return
        const point = mapToItem(null, 0, 0)
        _button.rect = Qt.rect(point.x, point.y, width, height)
    }

    onWidthChanged: Qt.callLater(_updateRect)
    onHeightChanged: Qt.callLater(_updateRect)

    Connections {
        target: VLCStyle
        function onAppWidthChanged() { Qt.callLater(root._updateRect) }
        function onAppHeightChanged() { Qt.callLater(root._updateRect) }
    }

    Widgets.CSDWindowButton {
        anchors.fill: parent
        visible: root._shown

        showHovered: root._button?.showHovered ?? false
        externalPressed: root._button?.externalPressed ?? false

        color: (root.action === CSDButton.Close && (hovered || showHovered)) ? "white" : theme.fg.primary
        hoverColor: (root.action === CSDButton.Close) ? "red" : theme.bg.primary.alpha(0.5)
        isThemeDark: theme.palette.isDark

        iconTxt: {
            switch (root.action) {
            case CSDButton.Minimize:
                return root.useWinIcons ? "\uE921" : VLCIcons.window_minimize
            case CSDButton.MaximizeRestore:
                if (root.useWinIcons)
                    return (MainCtx.intfMainWindow.visibility === Window.Maximized) ? "\uE923" : "\uE922"
                return (MainCtx.intfMainWindow.visibility === Window.Maximized) ? VLCIcons.window_restore
                                                                                  : VLCIcons.window_maximize
            default:
                return root.useWinIcons ? "\uE8BB" : VLCIcons.window_close
            }
        }

        onClicked: root._button?.click()
    }
}
