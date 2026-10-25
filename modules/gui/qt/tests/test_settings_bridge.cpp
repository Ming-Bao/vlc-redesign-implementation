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
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QSignalSpy>

#include "vlc_stub_modules.hpp"

#include "../dialogs/settings/settings_bridge.hpp"

#include <vlc_configuration.h>

// the extensions manager is not linked into this test (settings_extensions.cpp)
QAbstractItemModel* SettingsBridge::extensions() { return nullptr; }
void SettingsBridge::reloadExtensions() {}
void qtResetAllPreferences(qt_intf_t*) {}
void qtPromptRestartAfterReset(QWidget*, qt_intf_t*) {}

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

    void ranges() {
        const auto h = m_bridge->range("hue");
        QCOMPARE(h["min"].toDouble(), -180.0);
        QCOMPARE(h["max"].toDouble(), 180.0);
        QVERIFY(m_bridge->range("random").isEmpty());
        QVERIFY(m_bridge->range("no-such-option").isEmpty());
    }

    void extensionsGuards() {
        QVERIFY(!m_bridge->canRemoveExtension(-1));
        QVERIFY(!m_bridge->canRemoveExtension(0));   // no list in this env
        QVERIFY(!m_bridge->removeExtensionFile("/no/such/file.lua"));
        // a real file outside the user folder is refused and kept
        QTemporaryDir outside;
        QFile f(outside.filePath("x.lua"));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.close();
        QVERIFY(!m_bridge->removeExtensionFile(f.fileName()));
        QVERIFY(QFile::exists(f.fileName()));
        // inside the user folder (redirected to a temp dir, never the real one) it is removed
        QTemporaryDir data;
        qputenv("XDG_DATA_HOME", data.path().toUtf8());
        QVERIFY(QDir().mkpath(data.filePath("vlc/lua/extensions")));
        QFile g(data.filePath("vlc/lua/extensions/y.lua"));
        QVERIFY(g.open(QIODevice::WriteOnly));
        g.close();
        QVERIFY(m_bridge->removeExtensionFile(g.fileName()));
        QVERIFY(!QFile::exists(g.fileName()));
        qunsetenv("XDG_DATA_HOME");
        QVERIFY(!m_bridge->addExtension(QUrl::fromLocalFile("/no/such/file.lua")));
    }

    void installExtension() {
        QTemporaryDir src, dir;
        QVERIFY(src.isValid() && dir.isValid());
        const QString a = src.filePath("a#b%c.lua");
        QFile f(a); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("v1"); f.close();
        const QString dst = dir.filePath("a#b%c.lua");
        QVERIFY(SettingsBridge::installExtensionFile(a, dir.path()));
        QVERIFY(QFile::exists(dst));
        // picking the installed file itself (or a link to it) keeps it
        QVERIFY(SettingsBridge::installExtensionFile(dst, dir.path()));
        QCOMPARE(QFile(dst).size(), qint64(2));
        QVERIFY(QFile::link(dst, src.filePath("link.lua")));
        QVERIFY(SettingsBridge::installExtensionFile(src.filePath("link.lua"), dir.path()));
        QVERIFY(QFile::exists(dst));
        QVERIFY(!SettingsBridge::installExtensionFile(src.filePath("none.lua"), dir.path()));
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
