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
#ifndef VLC_QT_EFFECTS_UTIL_HPP
#define VLC_QT_EFFECTS_UTIL_HPP

#include <QString>
#include <QVector>
#include <utility>

// string helpers behind the player's effects panel; no libvlc dependency so they can be unit tested
namespace effects {

constexpr int EQZ_BANDS = 10;

QString toggleModule(const QString& list, const QString& module, bool add);
QString formatBands(const QVector<float>& bands);
QVector<float> parseBands(const QString& s);
// flip: 0 none, 1 horizontal, 2 vertical; rotation in degrees clockwise, applied after the flip
QString transformType(int flip, int rotation);
std::pair<int, int> parseTransform(const QString& type);

}

#endif
