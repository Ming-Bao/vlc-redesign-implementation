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
#include "util/folder_tree.hpp"

using folder_tree::Child;
using folder_tree::Range;
using folder_tree::splitRange;

static const QString R = "file:///lib/Videos";

static QStringList names(const std::vector<Child>& v)
{
    QStringList res;
    for (const Child& c : v)
        res << c.name;
    return res;
}

class TestFolderTree : public QObject
{
    Q_OBJECT
private slots:
    void rootFilter()
    {
        auto res = folder_tree::children({R + "/", "file:///lib/Empty/"}, {R + "/Shows/The Wand/S01/"}, "");
        QCOMPARE(res.size(), size_t(1));
        QCOMPARE(res[0].name, QString("Videos"));
        QCOMPARE(res[0].mrl, R);
    }
    void nextSegment()
    {
        auto res = folder_tree::children({R + "/"},
                            {R + "/Shows/The Wand/S01/", R + "/Shows/The Wand/S02/", R + "/Films/"}, R);
        QCOMPARE(names(res), QStringList({"Films", "Shows"}));
        QCOMPARE(res[0].mrl, R + "/Films");
        QCOMPARE(res[1].mrl, R + "/Shows");
    }
    void trailingSlashParent()
    {
        auto res = folder_tree::children({R + "/"}, {R + "/Shows/The Wand/S01/"}, R + "/Shows/");
        QCOMPARE(names(res), QStringList({"The Wand"}));
        QCOMPARE(res[0].mrl, R + "/Shows/The Wand");
    }
    void segmentBoundary()
    {
        QVERIFY(folder_tree::children({R + "/"}, {R + "/Shows2/a/"}, R + "/Shows").empty());
    }
    void rootIsMediaFolder()
    {
        auto res = folder_tree::children({R + "/"}, {R + "/"}, "");
        QCOMPARE(res.size(), size_t(1));
        QCOMPARE(res[0].mrl, R);
        QVERIFY(folder_tree::children({R + "/"}, {R + "/"}, R).empty());
    }
    void decodesNames()
    {
        auto res = folder_tree::children({R + "/"},
                            {R + "/My%20Shows/x/", R + "/Caf%C3%A9/", R + "/Bad%E9/", R + "/apple/"}, R);
        QCOMPARE(res.size(), size_t(4));
        QCOMPARE(res[0].name, QString("apple"));
        QCOMPARE(res[1].name, QString("Bad%E9"));
        QCOMPARE(res[2].name, QString::fromUtf8("Caf\xC3\xA9"));
        QCOMPARE(res[3].name, QString("My Shows"));
    }
    void caseTiebreak()
    {
        auto res = folder_tree::children({R + "/"}, {R + "/shows/", R + "/Films/", R + "/Shows/"}, R);
        QCOMPARE(names(res), QStringList({"Films", "Shows", "shows"}));
    }
    void outsideRoots()
    {
        QVERIFY(folder_tree::children({R + "/"}, {R + "/a/"}, "file:///elsewhere").empty());
    }
    void splitRange_foldersOnly()
    {
        Range r = splitRange(5, 0, 3);
        QCOMPARE(r.folderBegin, size_t(0));
        QCOMPARE(r.folderEnd, size_t(3));
        QVERIFY(!r.media);
    }
    void splitRange_straddle()
    {
        Range r = splitRange(5, 3, 4);
        QCOMPARE(r.folderBegin, size_t(3));
        QCOMPARE(r.folderEnd, size_t(5));
        QVERIFY(r.media);
        QCOMPARE(r.mediaOffset, size_t(0));
        QCOMPARE(r.mediaLimit, size_t(2));
    }
    void splitRange_mediaOnly()
    {
        Range r = splitRange(5, 7, 4);
        QCOMPARE(r.folderBegin, r.folderEnd);
        QVERIFY(r.media);
        QCOMPARE(r.mediaOffset, size_t(2));
        QCOMPARE(r.mediaLimit, size_t(4));
    }
    void splitRange_unlimited()
    {
        Range r = splitRange(5, 0, 0);
        QCOMPARE(r.folderBegin, size_t(0));
        QCOMPARE(r.folderEnd, size_t(5));
        QVERIFY(r.media);
        QCOMPARE(r.mediaOffset, size_t(0));
        QCOMPARE(r.mediaLimit, size_t(0));
    }
    // Go to Source: the levels from the entry point down to a media's folder
    void trail()
    {
        auto res = folder_tree::trail({"file:///lib/Other/", R + "/"}, R + "/My%20Shows/S01/");
        QCOMPARE(names(res), QStringList({"Videos", "My Shows", "S01"}));
        QCOMPARE(res[0].mrl, R);
        QCOMPARE(res[2].mrl, R + "/My%20Shows/S01");
        QCOMPARE(folder_tree::trail({R + "/"}, R).size(), size_t(1));
        QVERIFY(folder_tree::trail({R + "/"}, R + "2/a").empty());
        QVERIFY(folder_tree::trail({R + "/"}, "file:///elsewhere").empty());
    }
};

QTEST_GUILESS_MAIN(TestFolderTree)
#include "test_folder_tree.moc"
