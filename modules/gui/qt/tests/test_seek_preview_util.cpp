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
#include "player/seek_preview_util.hpp"

using namespace seekpreview;

class TestSeekPreviewUtil : public QObject
{
    Q_OBJECT
private slots:
    void discSchemesRejected()
    {
        for (const char* s : { "dvd", "DVD", "dvdsimple", "bluray", "vcd", "cdda" })
            QVERIFY2(!previewableScheme(s), s);
        for (const char* s : { "file", "smb", "nfs", "sftp", "ftp", "http", "https" })
            QVERIFY2(previewableScheme(s), s);
    }
    void clampPositionRange()
    {
        QCOMPARE(clampPosition(-0.5), 0.0);
        QCOMPARE(clampPosition(0.5), 0.5);
        QCOMPARE(clampPosition(1.0), 0.999);
        QCOMPARE(clampPosition(qQNaN()), 0.0);
    }
    void fitIntoBox()
    {
        QCOMPARE(fitInto({1920, 1080}, {252, 142}), QSize(252, 142));
        QCOMPARE(fitInto({1080, 1920}, {252, 142}), QSize(80, 142));
        QCOMPARE(fitInto({640, 480}, {252, 142}), QSize(189, 142));
        QCOMPARE(fitInto({}, {252, 142}), QSize(252, 142));
    }
    void latestOnlyCoalesces()
    {
        LatestOnly l;
        QVERIFY(l.request(0.1));
        QVERIFY(!l.request(0.2));
        QVERIFY(!l.request(0.3));
        QCOMPARE(l.finished(), std::optional<double>(0.3));
        QCOMPARE(l.finished(), std::optional<double>());
        QVERIFY(l.request(0.4));
    }
    void latestOnlyReset()
    {
        LatestOnly l;
        l.request(0.1);
        l.request(0.2);
        l.reset();
        QVERIFY(l.request(0.5));
        QCOMPARE(l.finished(), std::optional<double>());
    }
};

QTEST_GUILESS_MAIN(TestSeekPreviewUtil)
#include "test_seek_preview_util.moc"
