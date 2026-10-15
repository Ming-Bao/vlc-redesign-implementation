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
#include "player/effects_util.hpp"

using namespace effects;

class TestEffectsUtil : public QObject
{
    Q_OBJECT
private slots:
    void toggleAdds()      { QCOMPARE(toggleModule("", "adjust", true), QString("adjust")); }
    void toggleAppends()   { QCOMPARE(toggleModule("invert", "adjust", true), QString("invert:adjust")); }
    void toggleNoDup()     { QCOMPARE(toggleModule("invert:adjust", "adjust", true), QString("invert:adjust")); }
    void toggleRemoves()   { QCOMPARE(toggleModule("invert:adjust:sepia", "adjust", false), QString("invert:sepia")); }
    void toggleAbsent()    { QCOMPARE(toggleModule("invert", "adjust", false), QString("invert")); }
    void toggleDropsEmpty(){ QCOMPARE(toggleModule("::invert::", "sepia", true), QString("invert:sepia")); }

    void bandsFormat()
    {
        QCOMPARE(formatBands({1.24f, -3.f}), QString("1.2 -3.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0"));
    }
    void bandsParse()
    {
        const auto b = parseBands("1.5 x 30 -25");
        QCOMPARE(b.size(), EQZ_BANDS);
        QCOMPARE(b[0], 1.5f);
        QCOMPARE(b[1], 0.f);   // garbage
        QCOMPARE(b[2], 20.f);  // clamped
        QCOMPARE(b[3], -20.f); // clamped
        QCOMPARE(b[9], 0.f);   // missing
    }

    void transformTable_data()
    {
        QTest::addColumn<int>("flip");
        QTest::addColumn<int>("rot");
        QTest::addColumn<QString>("type");
        QTest::newRow("id")    << 0 << 0   << "";
        QTest::newRow("r90")   << 0 << 90  << "90";
        QTest::newRow("r180")  << 0 << 180 << "180";
        QTest::newRow("r270")  << 0 << 270 << "270";
        QTest::newRow("h")     << 1 << 0   << "hflip";
        QTest::newRow("h90")   << 1 << 90  << "antitranspose";
        QTest::newRow("h180")  << 1 << 180 << "vflip";
        QTest::newRow("h270")  << 1 << 270 << "transpose";
        QTest::newRow("v")     << 2 << 0   << "vflip";
        QTest::newRow("v90")   << 2 << 90  << "transpose";
        QTest::newRow("v180")  << 2 << 180 << "hflip";
        QTest::newRow("v270")  << 2 << 270 << "antitranspose";
        QTest::newRow("snap45")<< 0 << 45  << "90";
        QTest::newRow("snap-90")<< 0 << -90 << "270";
    }
    void transformTable()
    {
        QFETCH(int, flip); QFETCH(int, rot); QFETCH(QString, type);
        QCOMPARE(transformType(flip, rot), type);
    }

    void transformRoundTrip()
    {
        for (int flip = 0; flip < 3; ++flip)
            for (int rot = 0; rot < 360; rot += 90)
            {
                const QString t = transformType(flip, rot);
                const auto [f, r] = parseTransform(t);
                QCOMPARE(transformType(f, r), t);
            }
        QCOMPARE(parseTransform("bogus"), std::make_pair(0, 0));
        // ambiguous types read back with the smallest rotation, so "Vertical" stays vertical
        QCOMPARE(parseTransform("vflip"), std::make_pair(2, 0));
        QCOMPARE(parseTransform("hflip"), std::make_pair(1, 0));
        QCOMPARE(parseTransform("transpose"), std::make_pair(2, 90));
        QCOMPARE(parseTransform("antitranspose"), std::make_pair(1, 90));
    }
};

QTEST_GUILESS_MAIN(TestEffectsUtil)
#include "test_effects_util.moc"
