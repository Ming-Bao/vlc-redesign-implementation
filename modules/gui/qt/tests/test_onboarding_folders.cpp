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
#include <QDir>
#include <QFile>

#include "dialogs/onboarding/onboarding_folders.hpp"

class TestOnboardingFolders : public QObject
{
    Q_OBJECT
private slots:
    void expandHome_cases() {
        QCOMPARE(onboarding::expandHome("~", "/h"), QString("/h"));
        QCOMPARE(onboarding::expandHome("~/", "/h"), QString("/h"));
        QCOMPARE(onboarding::expandHome(" ~/My Videos/ ", "/h"), QString("/h/My Videos"));
        QCOMPARE(onboarding::expandHome("/abs/x/", "/h"), QString("/abs/x"));
        QCOMPARE(onboarding::expandHome("~other", "/h"), QString("~other"));
    }
    void displayPath_cases() {
        QCOMPARE(onboarding::displayPath("/h/Videos", "/h"), QString("~/Videos"));
        QCOMPARE(onboarding::displayPath("/h", "/h"), QString("~"));
        QCOMPARE(onboarding::displayPath("/hx/Videos", "/h"), QString("/hx/Videos"));
    }
    void fieldValid_cases() {
        QTemporaryDir d; QDir(d.path()).mkdir("My Videos");
        QFile f(d.path() + "/file"); QVERIFY(f.open(QIODevice::WriteOnly));
        QVERIFY(onboarding::fieldValid("  ", d.path()));
        QVERIFY(onboarding::fieldValid("~/My Videos", d.path()));
        QVERIFY(!onboarding::fieldValid("~/file", d.path()));
        QVERIFY(!onboarding::fieldValid("~/missing", d.path()));
    }
    void fieldValid_relativeIsInvalid() {
        QTemporaryDir d; QDir(d.path()).mkdir("My Videos");
        const QString old = QDir::currentPath();
        QVERIFY(QDir::setCurrent(d.path()));
        const bool rel = onboarding::fieldValid("My Videos", d.path());
        const bool other = onboarding::fieldValid("~other", d.path());
        QDir::setCurrent(old);
        QVERIFY(!rel);
        QVERIFY(!other);
    }
    void foldersToAdd_cases() {
        QCOMPARE(onboarding::foldersToAdd("/h/V", "/h/M"), (QStringList{"/h/V", "/h/M"}));
        QCOMPARE(onboarding::foldersToAdd("", "/h/M"), QStringList{"/h/M"});
        QCOMPARE(onboarding::foldersToAdd("/h", "/h/M"), QStringList{"/h"});        // music inside chosen
        QCOMPARE(onboarding::foldersToAdd("/h/M", "/h/M"), QStringList{"/h/M"});    // same
        QCOMPARE(onboarding::foldersToAdd("/h/Mu", "/h/M"), (QStringList{"/h/Mu", "/h/M"})); // prefix, not inside
        QCOMPARE(onboarding::foldersToAdd("/h/V", ""), QStringList{"/h/V"});
    }
};

QTEST_GUILESS_MAIN(TestOnboardingFolders)
#include "test_onboarding_folders.moc"
