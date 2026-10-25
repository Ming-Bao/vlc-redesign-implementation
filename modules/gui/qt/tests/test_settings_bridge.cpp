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
#include <QSignalSpy>

#include "vlc_stub_modules.hpp"

#include "../dialogs/settings/settings_bridge.hpp"

#include <vlc_configuration.h>

class TestClass : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase() {
        m_env = std::make_unique<VLCTestingEnv>();
        QVERIFY(m_env->init());
        m_bridge = std::make_unique<SettingsBridge>(m_env->intf);
    }

    void cleanupTestCase() {
        m_bridge.reset();
        m_env.reset();
    }

    void roundTripBool()   { auto& b = *m_bridge; b.setValue("random", true); QCOMPARE(b.value("random"), QVariant(true)); }
    void roundTripInt()    { auto& b = *m_bridge; b.setValue("long-jump-size", 120); QCOMPARE(b.value("long-jump-size").toLongLong(), 120); }
    void roundTripFloat()  { auto& b = *m_bridge; b.setValue("rate", 1.5); QCOMPARE(b.value("rate").toFloat(), 1.5f); }
    void roundTripString() { auto& b = *m_bridge; b.setValue("sub-language", "fre"); QCOMPARE(b.value("sub-language").toString(), QString("fre")); }
    void roundTripColor()  { auto& b = *m_bridge; b.setValue("freetype-color", "#FF8000"); QCOMPARE(b.value("freetype-color").toLongLong(), 0xFF8000); }

    void unknownOption() {
        auto& b = *m_bridge;
        QVERIFY(!b.exists("no-such-option"));
        QVERIFY(!b.value("no-such-option").isValid());
        QVERIFY(b.exists("random"));
        const int r = b.revision();
        b.setValue("no-such-option", 1);   // a failed write is not a change
        QCOMPARE(b.revision(), r);
    }

    void obsoleteOption() {
        QCOMPARE(config_GetType("spdif"), int(VLC_VAR_BOOL));   // still registered, but removed
        QVERIFY(!m_bridge->exists("spdif"));
    }

    void intChoices() {
        const auto c = m_bridge->choices("restore-playback-pos");
        QCOMPARE(c.size(), 3);
        QCOMPARE(c[0].toMap()["value"].toInt(), 0);
        QVERIFY(!c[0].toMap()["label"].toString().isEmpty());
    }

    void noChoices() { QVERIFY(m_bridge->choices("long-jump-size").isEmpty()); }

    void listToggle() {
        auto& b = *m_bridge;
        b.setValue("audio-filter", "");
        b.setListHas("audio-filter", "karaoke", true);
        b.setListHas("audio-filter", "normvol", true);
        QCOMPARE(b.value("audio-filter").toString(), QString("karaoke:normvol"));
        b.setListHas("audio-filter", "karaoke", false);
        QVERIFY(!b.listHas("audio-filter", "karaoke"));
        QVERIFY(b.listHas("audio-filter", "normvol"));
    }

    void listOnBadOption() {
        auto& b = *m_bridge;
        const int r = b.revision();
        for (const char* name : {"no-such-option", "random"}) {   // unknown, and not a string option
            QVERIFY(!b.listHas(name, "x"));
            b.setListHas(name, "x", true);
            QCOMPARE(b.revision(), r);
        }
    }

    void resetOne() {
        auto& b = *m_bridge;
        b.setValue("long-jump-size", 5);
        b.reset("long-jump-size");
        QCOMPARE(b.value("long-jump-size"), b.defaultValue("long-jump-size"));
    }

    void resetPrefix() {
        auto& b = *m_bridge;
        const auto d = b.defaultValue("key-play-pause");
        b.setValue("key-play-pause", "x");
        b.resetPrefixes({"key-"});
        QCOMPARE(b.value("key-play-pause"), d);
    }

    void revisionBumps() {
        auto& b = *m_bridge;
        const int r = b.revision();
        QSignalSpy spy(&b, &SettingsBridge::changed);
        b.setValue("random", false);
        QVERIFY(b.revision() > r);
        QCOMPARE(spy.size(), 1);
        QCOMPARE(spy[0][0].toString(), QString("random"));
    }

    void languages() {
        const auto l = m_bridge->languages();
        QVERIFY(l.size() > 100);
        QCOMPARE(l[0].toMap()["value"].toString(), QString());
        QCOMPARE(l[1].toMap()["label"].toString(), QString("Abkhazian"));
    }

    void helpText() { QVERIFY(!m_bridge->help("rate").isEmpty()); QVERIFY(m_bridge->help("no-such-option").isEmpty()); }

private:
    std::unique_ptr<VLCTestingEnv> m_env;
    std::unique_ptr<SettingsBridge> m_bridge;
};

QTEST_GUILESS_MAIN(TestClass)
#include "test_settings_bridge.moc"
