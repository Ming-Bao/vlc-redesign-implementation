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
#ifndef VLC_QT_M3U8_HPP
#define VLC_QT_M3U8_HPP

#include <QByteArray>
#include <QStringList>

// a playlist file: the header, then one MRL per line, in order
inline QByteArray toM3u8(const QStringList& mrls)
{
    QByteArray res = "#EXTM3U\n";
    for (const QString& mrl : mrls)
        res += mrl.toUtf8() + '\n';
    return res;
}

#endif
