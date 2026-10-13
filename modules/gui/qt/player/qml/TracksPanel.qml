
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
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

PlayerPanel {
    id: root

    tabs: [
        { text: qsTr("Video"), icon: VLCIcons.topbar_video },
        { text: qsTr("Audio"), icon: VLCIcons.topbar_music },
        { text: qsTr("Subtitles"), icon: VLCIcons.audiosub }
    ]
    currentTab: 2

    footerText: qsTr("Show Preferences")
    onFooterClicked: {
        root.close()
        DialogsProvider.prefsDialog()
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.videoTracks; singleChoice: true }
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.audioTracks }
        TrackSection { Layout.fillWidth: true; title: qsTr("Output Device"); model: Player.audioDevices; showNone: false }
    }

    ColumnLayout {
        spacing: 0

        TrackSection { Layout.fillWidth: true; title: qsTr("Embedded Tracks"); model: Player.subtitleTracks }

        TrackSection {
            Layout.fillWidth: true
            title: qsTr("External Tracks")

            actions: Widgets.IconToolButton {
                text: VLCIcons.add
                description: qsTr("Add subtitle file")
                onClicked: {
                    root.close()
                    DialogsProvider.loadSubtitlesFile()
                }
            }
        }
    }
}
