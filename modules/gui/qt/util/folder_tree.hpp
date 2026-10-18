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
#ifndef VLC_QT_FOLDER_TREE_HPP
#define VLC_QT_FOLDER_TREE_HPP

#include <QSet>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <algorithm>
#include <vector>

// Folder levels of the library, derived from the MRLs of the folders that
// hold media. Only QtCore, so it can run on the ML thread.
namespace folder_tree {

struct Child
{
    QString name;
    QString mrl; // no trailing slash
};

inline QString normalized(const QString& mrl)
{
    return mrl.endsWith('/') ? mrl.chopped(1) : mrl;
}

inline QString displayName(const QString& segment)
{
    const QString decoded = QUrl::fromPercentEncoding(segment.toUtf8());
    return decoded.contains(QChar::ReplacementCharacter) ? segment : decoded;
}

// Root level when parent is empty: the entry points that hold media.
// Otherwise the distinct next path segments below parent.
inline std::vector<Child> children(const QStringList& roots, const QStringList& mediaFolders,
                                   const QString& parent)
{
    std::vector<Child> res;
    if (parent.isEmpty())
    {
        for (const QString& root : roots)
        {
            const QString r = normalized(root);
            const QString prefix = r + '/';
            const bool hasMedia = std::any_of(mediaFolders.cbegin(), mediaFolders.cend(),
                [&](const QString& m) { return normalized(m) == r || m.startsWith(prefix); });
            if (hasMedia)
                res.push_back({displayName(r.mid(r.lastIndexOf('/') + 1)), r});
        }
    }
    else
    {
        const QString p = normalized(parent);
        const QString prefix = p + '/';
        QSet<QString> seen;
        for (const QString& m : mediaFolders)
        {
            if (!m.startsWith(prefix))
                continue;
            const QString segment = m.mid(prefix.size()).section('/', 0, 0);
            if (segment.isEmpty() || seen.contains(segment))
                continue;
            seen.insert(segment);
            res.push_back({displayName(segment), prefix + segment});
        }
    }
    std::sort(res.begin(), res.end(), [](const Child& a, const Child& b) {
        // case-sensitive tiebreak, so "Shows" and "shows" keep a stable order
        const int c = QString::compare(a.name, b.name, Qt::CaseInsensitive);
        return c != 0 ? c < 0 : QString::compare(a.name, b.name, Qt::CaseSensitive) < 0;
    });
    return res;
}

// One page [offset, offset+limit) over "nFolders folders then files";
// limit 0 = unlimited. media false: no files requested. media true with
// mediaLimit 0: all remaining files.
struct Range
{
    size_t folderBegin, folderEnd;
    size_t mediaOffset, mediaLimit;
    bool media;
};

inline Range splitRange(size_t nFolders, size_t offset, size_t limit)
{
    Range r;
    r.folderBegin = std::min(offset, nFolders);
    r.mediaOffset = offset > nFolders ? offset - nFolders : 0;
    if (limit == 0)
    {
        r.folderEnd = nFolders;
        r.media = true;
        r.mediaLimit = 0;
        return r;
    }
    const size_t end = offset + limit;
    r.folderEnd = std::min(end, nFolders);
    r.media = end > nFolders;
    r.mediaLimit = r.media ? end - nFolders - r.mediaOffset : 0;
    return r;
}

} // namespace folder_tree

#endif // VLC_QT_FOLDER_TREE_HPP
