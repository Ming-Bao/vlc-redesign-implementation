import QtQuick

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// the library's Playlists page
Widgets.IconToolButton {
    text: VLCIcons.playlists
    description: qsTr("Playlists")
    onClicked: {
        PlayerControlbarControls.leavePlayer()
        History.push(["playlists"])
    }

    AccessibleCompat.id: "playlistsButton"
}
