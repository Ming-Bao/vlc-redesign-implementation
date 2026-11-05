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
#ifndef VLC_QT_PLAYLIST_COVER_HPP
#define VLC_QT_PLAYLIST_COVER_HPP

#include <QString>
#include <QUrl>

#include <cstdint>

// The media library keeps no thumbnail for a playlist, so a picked cover is copied to <dir>/<id>.<ext>

// <userdata>/playlist-covers
QString coverDir();
// the cover file of a playlist, empty when there is none
QString customCoverPath(const QString& dir, int64_t playlistId);
// copies the image over any earlier cover of that id; false when it cannot be read or written
bool storeCustomCover(const QString& dir, int64_t playlistId, const QUrl& image);
void removeCustomCover(const QString& dir, int64_t playlistId);

#endif
