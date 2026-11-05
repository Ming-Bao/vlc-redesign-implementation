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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "saved_streams.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>

#include <algorithm>

static const QString kSuffix = QStringLiteral(".m3u8");

SavedStreams::SavedStreams(const QString& dir, QObject* parent)
    : QObject(parent)
    , m_dir(dir)
{
    reload();
}

QStringList SavedStreams::parseLinks(const QString& text)
{
    QStringList out;
    for (QString line : text.split('\n')) {
        line = line.trimmed();
        if (line.isEmpty())
            continue;
        out << (line.contains("://") ? line : "http://" + line);
    }
    return out;
}

QString SavedStreams::safeFileName(const QString& name)
{
    static const QRegularExpression bad(QStringLiteral("[^\\p{L}\\p{N} _-]"));
    QString s = name.trimmed();
    s.replace(bad, "_");
    return s.isEmpty() ? QStringLiteral("stream") : s;
}

bool SavedStreams::exists(const QString& name) const
{
    return QFile::exists(QDir(m_dir).filePath(safeFileName(name) + kSuffix));
}

QVariantMap SavedStreams::save(const QString& name, const QStringList& links)
{
    if (links.isEmpty() || !QDir().mkpath(m_dir))
        return {};
    const QString title = name.trimmed();
    const QString path = QDir(m_dir).filePath(safeFileName(title) + kSuffix);
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return {};
    f.write("#EXTM3U\n#PLAYLIST:" + title.toUtf8() + "\n");
    for (const QString& l : links)
        f.write(l.toUtf8() + "\n");
    if (!f.commit())
        return {};
    reload();
    return {{"name", title},
            {"mrl", links.size() == 1 ? links.first() : QUrl::fromLocalFile(path).toString()},
            {"path", path}};
}

bool SavedStreams::remove(const QString& path)
{
    // only the files this class wrote
    const QFileInfo info(path);
    if (info.absoluteDir() != QDir(m_dir) || info.suffix() != "m3u8" || !QFile::remove(path))
        return false;
    reload();
    return true;
}

void SavedStreams::reload()
{
    QVariantList list;
    const QDir dir(m_dir);
    for (const QFileInfo& info : dir.entryInfoList({"*" + kSuffix}, QDir::Files)) {
        QString name = info.completeBaseName();
        QStringList links;
        QFile f(info.filePath());
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            while (!f.atEnd()) {
                const QString line = QString::fromUtf8(f.readLine()).trimmed();
                if (line.startsWith("#PLAYLIST:"))
                    name = line.mid(10);
                else if (!line.isEmpty() && !line.startsWith('#'))
                    links << line;
            }
        }
        list.push_back(QVariantMap{{"name", name},
                                   {"mrl", links.size() == 1 ? links.first() : QUrl::fromLocalFile(info.filePath()).toString()},
                                   {"path", info.filePath()}});
    }
    std::sort(list.begin(), list.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap()["name"].toString().localeAwareCompare(b.toMap()["name"].toString()) < 0;
    });
    m_entries = list;
    emit entriesChanged();
}
