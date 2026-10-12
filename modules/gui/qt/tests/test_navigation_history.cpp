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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QTest>
#include <QSignalSpy>

#include "../util/navigation_history.hpp"

class TestNavigationHistory : public QObject
{
    Q_OBJECT
private slots:
    void init() { m_h = new NavigationHistory(this); m_h->update({"home"}); }
    void cleanup() { delete m_h; m_h = nullptr; }

    void testInitiallyNoForward() {
        QVERIFY(m_h->isNextEmpty());
        m_h->next();
        QCOMPARE(m_h->viewPath(), QStringList{"home"});
    }

    void testPreviousThenNextRoundTrip() {
        m_h->push({"video"});
        m_h->push({"video", "all"});
        QSignalSpy nextEmpty(m_h, &NavigationHistory::nextEmptyChanged);

        m_h->previous();
        QCOMPARE(m_h->viewPath(), (QStringList{"video"}));
        QVERIFY(!m_h->isNextEmpty());
        QCOMPARE(nextEmpty.count(), 1);

        m_h->next();
        QCOMPARE(m_h->viewPath(), (QStringList{"video", "all"}));
        QVERIFY(m_h->isNextEmpty());
        QVERIFY(!m_h->isPreviousEmpty());
        QCOMPARE(nextEmpty.count(), 2);
    }

    void testPushClearsForward() {
        m_h->push({"video"});
        m_h->previous();
        QVERIFY(!m_h->isNextEmpty());
        m_h->push({"music"});
        QVERIFY(m_h->isNextEmpty());
        m_h->next();
        QCOMPARE(m_h->viewPath(), QStringList{"music"});
    }

    void testNextKeepsProperties() {
        m_h->push({"video"}, QVariantMap{{"initialIndex", 3}});
        m_h->previous();
        m_h->next();
        QCOMPARE(m_h->viewProp()->value("initialIndex").toInt(), 3);
    }

private:
    NavigationHistory* m_h = nullptr;
};

QTEST_GUILESS_MAIN(TestNavigationHistory)
#include "test_navigation_history.moc"
