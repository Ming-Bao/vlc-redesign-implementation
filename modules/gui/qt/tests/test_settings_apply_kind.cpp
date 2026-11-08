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

#include "dialogs/settings/settings_apply_kind.hpp"

class TestClass : public QObject
{
    Q_OBJECT
private slots:
    void kinds() {
        using namespace settingsapply;
        QCOMPARE(kindOf("aspect-ratio"), Kind::OutputVar);
        QCOMPARE(kindOf("audio-filter"), Kind::OutputVar);
        QCOMPARE(kindOf("hue"), Kind::OutputVar);
        QCOMPARE(kindOf("rate"), Kind::Player);
        QCOMPARE(kindOf("loop"), Kind::Player);
        QCOMPARE(kindOf("qt-max-volume"), Kind::Interface);
        QCOMPARE(kindOf("qt-fs-controller"), Kind::Interface);
        // shadowed by a long-lived object (player, aout, free vout): pushed to it so the next video reads them
        QCOMPARE(kindOf("audio-language"), Kind::Player);
        QCOMPARE(kindOf("sub-language"), Kind::Player);
        QCOMPARE(kindOf("audio-visual"), Kind::OutputVar);
        QCOMPARE(kindOf("align"), Kind::OutputVar);
        QCOMPARE(kindOf("monitor-par"), Kind::OutputVar);
        QCOMPARE(kindOf("norm-max-level"), Kind::OutputVar);
    }
    void emptyNameIgnored() { QCOMPARE(settingsapply::kindOf(""), settingsapply::Kind::None); }
    void neverPushed() { // no safe live push: it would act at once, reset what plays, or has no public setter
        for (const char* o : {"fullscreen", "qt-minimal-view", "volume-save", "aout", "dec-dev", "sout-audio"})
            QCOMPARE(settingsapply::kindOf(o), settingsapply::Kind::None);
    }
};

QTEST_GUILESS_MAIN(TestClass)
#include "test_settings_apply_kind.moc"
