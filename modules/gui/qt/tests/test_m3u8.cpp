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
#include "medialibrary/m3u8.hpp"

class TestM3u8 : public QObject
{
    Q_OBJECT
private slots:
    void mrlsInOrder()
    {
        QCOMPARE(toM3u8({"file:///a/One.mkv", "file:///b/D%C3%A9j%C3%A0.mkv"}),
                 QByteArray("#EXTM3U\nfile:///a/One.mkv\nfile:///b/D%C3%A9j%C3%A0.mkv\n"));
    }

    void empty()
    {
        QCOMPARE(toM3u8({}), QByteArray("#EXTM3U\n"));
    }
};

QTEST_GUILESS_MAIN(TestM3u8)
#include "test_m3u8.moc"
