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
#include "onboarding_folders.hpp"

#include <QDir>
#include <QFileInfo>

namespace onboarding {

static bool isInside(const QString& path, const QString& dir)
{
    return !dir.isEmpty() && QDir::cleanPath(path).startsWith(QDir::cleanPath(dir) + '/');
}

QString expandHome(const QString& text, const QString& home)
{
    QString t = text.trimmed();
    if (t == QLatin1String("~"))
        t = home;
    else if (t.startsWith(QLatin1String("~/")))
        t = home + t.mid(1);
    return QDir::cleanPath(t);
}

QString displayPath(const QString& path, const QString& home)
{
    if (path == home)
        return QStringLiteral("~");
    if (isInside(path, home))
        return QStringLiteral("~") + path.mid(home.size());
    return path;
}

bool fieldValid(const QString& text, const QString& home)
{
    return text.trimmed().isEmpty() || QFileInfo(expandHome(text, home)).isDir();
}

QStringList foldersToAdd(const QString& chosen, const QString& music)
{
    QStringList l;
    if (!chosen.isEmpty())
        l << chosen;
    if (!music.isEmpty() && music != chosen && !isInside(music, chosen))
        l << music;
    return l;
}

}
