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

#include "dialogs/network/saved_streams.hpp"

class TestSavedStreams : public QObject
{
    Q_OBJECT
private slots:
    void parseLinks_cases() {
        QCOMPARE(SavedStreams::parseLinks("\n a.com/x \n\nhttps://b/y\n"),
                 (QStringList{"http://a.com/x", "https://b/y"}));
        QCOMPARE(SavedStreams::parseLinks("  \n"), QStringList{});
    }
    void safeFileName_staysInside() {
        QCOMPARE(SavedStreams::safeFileName("Fav/TV"), QString("Fav_TV"));
        QVERIFY(!SavedStreams::safeFileName("../../x").contains('/'));
        QVERIFY(!SavedStreams::safeFileName("..").startsWith('.'));
        QVERIFY(!SavedStreams::safeFileName("///").isEmpty());
    }
    void save_roundTrip() {
        QTemporaryDir dir; SavedStreams s(dir.path());
        auto one = s.save("Fav/TV", {"http://a/x"});
        QCOMPARE(one["name"].toString(), QString("Fav/TV"));          // title as typed
        QCOMPARE(one["mrl"].toString(), QString("http://a/x"));       // single URL browses the URL
        auto two = s.save("Two", {"http://a/x", "http://b/y"});
        QVERIFY(two["mrl"].toString().endsWith("Two.m3u8"));
        QCOMPARE(s.entries().size(), 2);
        QVERIFY(s.exists("Two"));
        QVERIFY(s.exists("Fav_TV"));
        SavedStreams again(dir.path());                                // read back from disk
        QCOMPARE(again.entries().size(), 2);
        QVERIFY(again.remove(two["path"].toString()));
        QCOMPARE(again.entries().size(), 1);
    }
    void save_createsDirAndRejectsEmpty() {
        QTemporaryDir dir; SavedStreams s(dir.path() + "/sub/dir");
        QVERIFY(s.save("x", {}).isEmpty());
        QVERIFY(!s.save("x", {"http://a/x"}).isEmpty());
        QVERIFY(!s.remove(dir.path() + "/outside.m3u8"));             // only files inside the directory
    }
};

QTEST_GUILESS_MAIN(TestSavedStreams)
#include "test_saved_streams.moc"
