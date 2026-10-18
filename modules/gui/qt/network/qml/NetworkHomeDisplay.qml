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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util
import VLC.Network
import VLC.Dialogs

// the Network root (sidebar variant Figma 858:5294): Add Network Stream, Podcasts, Radio,
// then the shares found on the local network
LibraryRootPage {
    id: root

    // the LAN shares' data, one map per row of deviceModel
    property var shares: []

    // the Network loader's path (pagePrefix ends with this page's own name)
    readonly property var _networkPath: pagePrefix.slice(0, -1)

    title: qsTr("Network")
    // the view toggle stays on Network (the Music root has none)
    hasGridListMode: true

    tiles: Helpers.withShares([
        { glyph: VLCIcons.add, text: qsTr("Add Network Stream"), add: true },
        { glyph: VLCIcons.topbar_network, text: qsTr("Podcasts"), page: "podcasts" },
        { glyph: VLCIcons.topbar_network, text: qsTr("Radio"), page: "radio" }
    ], shares, VLCIcons.folder)

    function _rebuildShares() {
        const list = []
        for (let i = 0; i < deviceModel.count; ++i)
            list.push(deviceModel.getDataAt(i))
        shares = list
    }

    onTileActivated: (tile, index, reason) => {
        if (tile.add) {
            DialogsProvider.openNetDialog()
        } else if (tile.page) {
            History.push([..._networkPath, tile.page], reason)
        } else {
            const data = deviceModel.getDataAt(tile.share)
            if (data.type === NetworkMediaModel.TYPE_DIRECTORY
                    || data.type === NetworkMediaModel.TYPE_NODE
                    || data.type === NetworkMediaModel.TYPE_PLAYLIST)
                History.push([..._networkPath, "browse"], { tree: data.tree }, reason)
            else
                deviceModel.addAndPlay(tile.share)
        }
    }

    onTileMenuRequested: (tile, index, globalPos) => {
        if (tile.share !== undefined)
            contextMenu.popup([deviceModel.index(tile.share, 0)], globalPos)
    }

    NetworkDeviceModel {
        id: deviceModel

        ctx: MainCtx
        sd_source: NetworkDeviceModel.CAT_LAN
        source_name: "*"

        onCountChanged: root._rebuildShares()
        onLoadingChanged: root._rebuildShares()
    }

    NetworkDeviceContextMenu {
        id: contextMenu

        model: deviceModel
        ctx: MainCtx
    }
}
