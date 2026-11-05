/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include <QTest>

#include "dialogs/subtitles/subtitle_matching.hpp"

class TestSubtitleMatching : public QObject
{
    Q_OBJECT
private slots:
    void matchSubtitles_cases() {
        const QStringList media{"The_Wand_S01E01.mp4", "The_Wand_S01E02.mp4", "Other.mkv"};
        // normalised stems, as in the video
        QCOMPARE(matchSubtitles(media, {"thewand_s01e02.srt", "thewand_s01e01.srt"}), (QVector<int>{1, 0, -1}));
        // subtitle stem extends the media stem
        QCOMPARE(matchSubtitles({"The_Wand_S01E01.mp4"}, {"The_Wand_S01E01_English.srt"}), QVector<int>{0});
        // SxxEyy token, any padding
        QCOMPARE(matchSubtitles({"Show.S01E02.1080p.mkv"}, {"s1e2.ass"}), QVector<int>{0});
        // each subtitle is used once; an exact match beats an earlier prefix match
        QCOMPARE(matchSubtitles({"a.mp4", "a2.mp4"}, {"a2.srt"}), (QVector<int>{-1, 0}));
        // no candidates
        QCOMPARE(matchSubtitles({"a.mp4"}, {}), QVector<int>{-1});
    }
    void matchSubtitles_tokenDoesNotCrossEpisodes() {
        QCOMPARE(matchSubtitles({"x.S01E01.mkv"}, {"y.s01e02.srt"}), QVector<int>{-1});
        // a used subtitle is not offered twice
        QCOMPARE(matchSubtitles({"a.S1E1.mkv", "b.S1E1.mkv"}, {"c.s01e01.srt"}), (QVector<int>{0, -1}));
    }
    void subtitleCandidates_filtersAndSorts() {
        QCOMPARE(subtitleCandidates({"b.SRT", "a.ass", "movie.mkv", "c.txt", "d.idx"}, "*.cdg;*.idx;*.srt;*.ass"),
                 (QStringList{"a.ass", "b.SRT", "d.idx"}));
    }
    void locationBreadcrumb_cases() {
        QCOMPARE(locationBreadcrumb("/home/u/Videos/Shows/The Wand/S01", "/home/u"),
                 QString("Videos / Shows / The Wand / S01"));
        QCOMPARE(locationBreadcrumb("/mnt/disk/Shows", "/home/u"), QString("mnt / disk / Shows"));
        QCOMPARE(locationBreadcrumb("/home/user2/Videos", "/home/u"), QString("home / user2 / Videos"));
        QCOMPARE(locationBreadcrumb({}, "/home/u"), QString{});
    }
};

QTEST_GUILESS_MAIN(TestSubtitleMatching)
#include "test_subtitle_matching.moc"
