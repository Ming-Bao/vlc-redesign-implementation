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
.pragma library
.import VLC.PlayerControls as PC

// The Customize Player palette, in Figma order (2107:5604): HDR isn't built. The title bar's controls follow, and what
// the default bars hold, so that anything dragged off can come back. *(my call: no frame shows these unplaced.)*
const items = [
    { id: PC.ControlListModel.WIDGET_SPACER, label: qsTr("Spacer"), repeats: true },
    { id: PC.ControlListModel.DIVIDER, label: qsTr("Divider"), repeats: true },
    { id: PC.ControlListModel.PLAYBACK_SPEED_BUTTON, label: qsTr("Playback Speed") },
    { id: PC.ControlListModel.JUMP_FW_10_BUTTON, label: qsTr("Forward 10s") },
    { id: PC.ControlListModel.JUMP_BACK_10_BUTTON, label: qsTr("Backward 10s") },
    { id: PC.ControlListModel.SKIP_FW_BUTTON, label: qsTr("Forward 15s") },
    { id: PC.ControlListModel.SKIP_BACK_BUTTON, label: qsTr("Backward 15s") },
    { id: PC.ControlListModel.STOP_BUTTON, label: qsTr("Stop") },
    { id: PC.ControlListModel.LOOP_BUTTON, label: qsTr("Repeat") },
    { id: PC.ControlListModel.RANDOM_BUTTON, label: qsTr("Shuffle") },
    { id: PC.ControlListModel.RECORD_BUTTON, label: qsTr("Record") },
    { id: PC.ControlListModel.SNAPSHOT_BUTTON, label: qsTr("Snapshot") },
    { id: PC.ControlListModel.PLAYER_SWITCH_BUTTON, label: qsTr("Picture in Picture") },
    { id: PC.ControlListModel.ZOOM_BUTTON, label: qsTr("Zoom") },
    { id: PC.ControlListModel.SIDE_PANEL_BUTTON, label: qsTr("Right Sidebar") },
    { id: PC.ControlListModel.QUIT_BUTTON, label: qsTr("Quit VLC") },
    { id: PC.ControlListModel.SETTINGS_BUTTON, label: qsTr("VLC Settings") },
    { id: PC.ControlListModel.HOME_BUTTON, label: qsTr("Go Home") },
    { id: PC.ControlListModel.THUMBNAIL_WIDGET, label: qsTr("Thumbnail") },
    { id: PC.ControlListModel.FILE_NAME_WIDGET, label: qsTr("File Name") },
    { id: PC.ControlListModel.ARTIST_NAME_WIDGET, label: qsTr("Artist Name") },
    { id: PC.ControlListModel.FOLDER_NAME_WIDGET, label: qsTr("Folder Name") },
    { id: PC.ControlListModel.PLAYLIST_NAME_WIDGET, label: qsTr("Playlist Name") },
    { id: PC.ControlListModel.INFO_BUTTON, label: qsTr("Properties") },
    { id: PC.ControlListModel.REPLAY_BUTTON, label: qsTr("Replay") },
    { id: PC.ControlListModel.CHAPTERS_BUTTON, label: qsTr("Chapters") },
    { id: PC.ControlListModel.FAVORITE_BUTTON, label: qsTr("Favorite") },
    { id: PC.ControlListModel.BOOKMARK_BUTTON, label: qsTr("Bookmark") },
    { id: PC.ControlListModel.BOOKMARKS_BUTTON, label: qsTr("Bookmarks") },
    { id: PC.ControlListModel.PLAYLISTS_BUTTON, label: qsTr("Playlists") },

    { id: PC.ControlListModel.MORE_MENU, label: qsTr("More") },
    { id: PC.ControlListModel.LIBRARY_PANEL, label: qsTr("Library Sidebar") },
    { id: PC.ControlListModel.FOLDER_CHIP, label: qsTr("Folder") },
    { id: PC.ControlListModel.MEDIA_TITLE, label: qsTr("Title") },
    { id: PC.ControlListModel.WINDOW_MINIMIZE, label: qsTr("Minimize") },
    { id: PC.ControlListModel.WINDOW_MAXIMIZE, label: qsTr("Maximize") },
    { id: PC.ControlListModel.WINDOW_CLOSE, label: qsTr("Close") },

    { id: PC.ControlListModel.PREVIOUS_BUTTON, label: qsTr("Previous") },
    { id: PC.ControlListModel.PLAY_BUTTON, label: qsTr("Play") },
    { id: PC.ControlListModel.NEXT_BUTTON, label: qsTr("Next") },
    { id: PC.ControlListModel.VOLUME, label: qsTr("Volume") },
    { id: PC.ControlListModel.LANG_BUTTON, label: qsTr("Languages and Tracks") },
    { id: PC.ControlListModel.EXTENDED_BUTTON, label: qsTr("Extended Settings") },
    { id: PC.ControlListModel.PLAYLIST_BUTTON, label: qsTr("Play Queue") },
    { id: PC.ControlListModel.FULLSCREEN_BUTTON, label: qsTr("Fullscreen") }
]

// the entries to show: everything not placed, and what may be placed many times
function available(items, placedIds) {
    return items.filter(i => i.repeats || !placedIds.includes(i.id))
}
