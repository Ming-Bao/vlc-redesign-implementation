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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "subtitle_matching.hpp"

#include <QDir>
#include <QRegularExpression>

#include <functional>
#include <utility>

namespace {

QString stemOf(const QString& name)
{
    const int dot = name.lastIndexOf('.');
    return dot > 0 ? name.left(dot) : name;
}

QString normalise(const QString& stem)
{
    QString out;
    for (const QChar c : stem.toLower())
        if (c.isLetterOrNumber())
            out += c;
    return out;
}

// (season, episode) from the raw stem, {-1, -1} without one
std::pair<qint64, qint64> episodeToken(const QString& stem)
{
    static const QRegularExpression re("s(\\d+)e(\\d+)", QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(stem);
    if (!m.hasMatch())
        return {-1, -1};
    return {m.captured(1).toLongLong(), m.captured(2).toLongLong()};
}

} // namespace

QVector<int> matchSubtitles(const QStringList& mediaNames, const QStringList& subtitleNames)
{
    struct Entry { QString stem, norm; std::pair<qint64, qint64> token; };
    auto entries = [](const QStringList& names) {
        QVector<Entry> v;
        for (const QString& n : names) {
            const QString stem = stemOf(n);
            v.push_back({stem, normalise(stem), episodeToken(stem)});
        }
        return v;
    };
    const QVector<Entry> media = entries(mediaNames);
    const QVector<Entry> subs = entries(subtitleNames);

    QVector<int> result(media.size(), -1);
    QVector<bool> used(subs.size(), false);

    using Test = std::function<bool(const Entry& m, const Entry& s)>;
    const Test passes[] = {
        [](const Entry& m, const Entry& s) { return m.norm == s.norm; },
        [](const Entry& m, const Entry& s) { return !m.norm.isEmpty() && s.norm.startsWith(m.norm); },
        [](const Entry& m, const Entry& s) { return m.token.first >= 0 && m.token == s.token; },
    };
    for (const Test& test : passes)
        for (int i = 0; i < media.size(); ++i) {
            if (result[i] >= 0)
                continue;
            for (int j = 0; j < subs.size(); ++j)
                if (!used[j] && test(media[i], subs[j])) {
                    result[i] = j;
                    used[j] = true;
                    break;
                }
        }
    return result;
}

QStringList subtitleCandidates(const QStringList& fileNames, const QString& extensions)
{
    QStringList suffixes;
    for (const QString& e : extensions.split(';', Qt::SkipEmptyParts))
        suffixes << e.trimmed().mid(1).toLower(); // "*.srt" -> ".srt"

    QStringList out;
    for (const QString& n : fileNames)
        for (const QString& s : suffixes)
            if (n.toLower().endsWith(s)) {
                out << n;
                break;
            }
    out.sort(Qt::CaseInsensitive);
    return out;
}

QString locationBreadcrumb(const QString& dir, const QString& home)
{
    if (dir.isEmpty())
        return {};
    QString path = QDir::cleanPath(dir);
    const QString h = QDir::cleanPath(home);
    if (!h.isEmpty() && path.startsWith(h + '/'))
        path = path.mid(h.size());
    return path.split('/', Qt::SkipEmptyParts).join(" / ");
}
