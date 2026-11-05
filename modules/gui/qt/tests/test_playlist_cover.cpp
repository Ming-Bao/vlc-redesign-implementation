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
#include <QTest>
#include <QTemporaryDir>
#include <QImage>
#include <QFile>
#include <QDir>

#include "dialogs/playlists/playlist_cover.hpp"

class TestPlaylistCover : public QObject
{
    Q_OBJECT
private slots:
    void cover_lifecycle() {
        QTemporaryDir dir, src;
        const QString png = src.filePath("c.png");
        QImage(4, 4, QImage::Format_RGB32).save(png);
        QCOMPARE(customCoverPath(dir.path(), 7), QString{});
        QVERIFY(storeCustomCover(dir.path(), 7, QUrl::fromLocalFile(png)));
        QVERIFY(customCoverPath(dir.path(), 7).endsWith("/7.png"));
        QVERIFY(QFile::exists(png));                                   // the source is copied, not moved
        const QString jpg = src.filePath("c.jpg");
        QImage(4, 4, QImage::Format_RGB32).save(jpg);
        QVERIFY(storeCustomCover(dir.path(), 7, QUrl::fromLocalFile(jpg)));
        QVERIFY(customCoverPath(dir.path(), 7).endsWith("/7.jpg"));    // no stale png wins
        QCOMPARE(customCoverPath(dir.path(), 70), QString{});          // 70 isn't 7
        removeCustomCover(dir.path(), 7);
        QCOMPARE(customCoverPath(dir.path(), 7), QString{});
        QVERIFY(!storeCustomCover(dir.path(), 8, QUrl::fromLocalFile(src.filePath("missing.png"))));
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files | QDir::Hidden).size(), 0); // no temp file left
    }
};

QTEST_GUILESS_MAIN(TestPlaylistCover)
#include "test_playlist_cover.moc"
