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
#include <algorithm>
#include "player/waveform_util.hpp"

using namespace waveform;

class TestWaveformUtil : public QObject
{
    Q_OBJECT
private slots:
    void foldBucketsByTime()
    {
        QList<float> b(BUCKETS, 0.f);
        // 8 Hz over a 1 s media: sample i sits at i/8 s, i.e. bucket i*128
        const float s[8] = { 0.1f, -0.5f, 0.2f, 0.f, 0.f, 0.f, 0.f, -0.9f };
        foldSamples(b, s, 8, 0, 8, 1000000);
        QCOMPARE(b[0], 0.1f);
        QCOMPARE(b[128], 0.5f);   // absolute value
        QCOMPARE(b[256], 0.2f);
        QCOMPARE(b[896], 0.9f);
        QCOMPARE(b[1], 0.f);
    }
    void foldKeepsMax()
    {
        QList<float> b(BUCKETS, 0.f);
        const float loud[1] = { 0.8f }, quiet[1] = { 0.3f };
        foldSamples(b, loud, 1, 0, 8, 1000000);
        foldSamples(b, quiet, 1, 0, 8, 1000000);
        QCOMPARE(b[0], 0.8f);
    }
    void foldDropsPastLength()
    {
        QList<float> b(BUCKETS, 0.f);
        const float s[2] = { 1.f, 1.f };
        foldSamples(b, s, 2, 1000000, 8, 1000000);   // starts at the end
        QCOMPARE(*std::max_element(b.cbegin(), b.cend()), 0.f);
    }
    void foldIgnoresBadInput()
    {
        QList<float> b(BUCKETS, 0.f);
        const float s[1] = { 1.f };
        foldSamples(b, s, 1, 0, 0, 1000000);   // no rate
        foldSamples(b, s, 1, 0, 8, 0);         // no length
        foldSamples(b, s, 1, -1, 8, 1000000);  // before the start
        QCOMPARE(*std::max_element(b.cbegin(), b.cend()), 0.f);
    }

    void resampleKeepsSpanPeak()
    {
        const QList<float> p { 0.f, 1.f, 0.f, 0.f, 0.f, 0.f, 0.5f, 0.f };
        QCOMPARE(resample(p, 2), (QList<float>{ 1.f, 0.5f }));
    }
    void resampleUpsamples()
    {
        const QList<float> p { 0.2f, 0.4f };
        QCOMPARE(resample(p, 4), (QList<float>{ 0.2f, 0.2f, 0.4f, 0.4f }));
    }
    void resampleEmpty()
    {
        QCOMPARE(resample({}, 3), (QList<float>{ 0.f, 0.f, 0.f }));
        QCOMPARE(resample({ 1.f }, 0), QList<float>{});
    }

    void normalizeScales()
    {
        QList<float> p { 0.25f, 0.5f };
        normalize(p);
        QCOMPARE(p, (QList<float>{ 0.5f, 1.f }));
        QList<float> z { 0.f, 0.f };
        normalize(z);
        QCOMPARE(z, (QList<float>{ 0.f, 0.f }));
    }

    void barHeightSnaps_data()
    {
        QTest::addColumn<float>("peak");
        QTest::addColumn<qreal>("h");
        QTest::newRow("silent") << 0.f   << 2.;
        QTest::newRow("full")   << 1.f   << 14.;
        QTest::newRow("half")   << 0.5f  << 8.;
        QTest::newRow("tiny")   << 0.04f << 2.;
        QTest::newRow("small")  << 0.09f << 4.;
        QTest::newRow("over")   << 1.5f  << 14.;
        QTest::newRow("under")  << -1.f  << 2.;
    }
    void barHeightSnaps()
    {
        QFETCH(float, peak);
        QFETCH(qreal, h);
        QCOMPARE(barHeight(peak, 2., 14., 2.), h);
    }
};

QTEST_GUILESS_MAIN(TestWaveformUtil)
#include "test_waveform_util.moc"
