/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef VLC_QT_SUBTITLE_MATCHING_HPP
#define VLC_QT_SUBTITLE_MATCHING_HPP

#include <QString>
#include <QStringList>
#include <QVector>

// For each media name, the index of its subtitle in subtitleNames, or -1.
// Passes, in order: equal normalised stems, a subtitle stem starting with the
// media stem, the same SxxEyy token. A subtitle is used once.
QVector<int> matchSubtitles(const QStringList& mediaNames, const QStringList& subtitleNames);

// The names whose extension is in `extensions` ("*.srt;*.ass", as EXTENSIONS_SUBTITLE), sorted
QStringList subtitleCandidates(const QStringList& fileNames, const QString& extensions);

// "Videos / Shows / S01": `dir` relative to `home` when inside it, else from the root
QString locationBreadcrumb(const QString& dir, const QString& home);

#endif
