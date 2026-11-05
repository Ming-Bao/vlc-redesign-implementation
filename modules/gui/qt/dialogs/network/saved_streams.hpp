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
#ifndef VLC_QT_SAVED_STREAMS_HPP
#define VLC_QT_SAVED_STREAMS_HPP

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// The network streams saved by the Open Network Stream dialog: one m3u8 file per name in a directory
// (singleton "SavedStreams" in VLC.Dialogs)
class SavedStreams : public QObject
{
    Q_OBJECT
    // each { name, mrl, path }; mrl is the single URL, or else the file
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged FINAL)

public:
    explicit SavedStreams(const QString& dir, QObject* parent = nullptr);

    QVariantList entries() const { return m_entries; }

    // one link per non-blank line; a line without "://" gets "http://"
    Q_INVOKABLE static QStringList parseLinks(const QString& text);
    // a file name that cannot leave the directory
    Q_INVOKABLE static QString safeFileName(const QString& name);
    Q_INVOKABLE bool exists(const QString& name) const;
    // writes (or overwrites) the entry; an empty map on failure
    Q_INVOKABLE QVariantMap save(const QString& name, const QStringList& links);
    Q_INVOKABLE bool remove(const QString& path);

signals:
    void entriesChanged();

private:
    void reload();

    QString m_dir;
    QVariantList m_entries;
};

#endif
