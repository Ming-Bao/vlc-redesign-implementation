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
#include <QApplication>
#include <QMenu>
#include <QScopeGuard>
#include <QVariantMap>
#include "style/menustyle.hpp"

class TestMenuStyle : public QObject
{
    Q_OBJECT
private slots:
    void shortcutText()
    {
        QCOMPARE(menuShortcutText(QKeySequence("Ctrl+O")), QString("Ctrl + O"));
        QCOMPARE(menuShortcutText(QKeySequence("Ctrl+Shift+O")), QString("Ctrl + Shift + O"));
        QCOMPARE(menuShortcutText(QKeySequence("Shift+F1")), QString("Shift + F1"));
        QCOMPARE(menuShortcutText(QKeySequence(Qt::CTRL | Qt::Key_Plus)), QString("Ctrl + +"));
        QCOMPARE(menuShortcutText(QKeySequence("Space")), QString("Space"));
    }
    void labelText()
    {
        QCOMPARE(menuLabelText("Open &File(s)"), QString("Open File(s)"));
        QCOMPARE(menuLabelText("Tom && Jerry"), QString("Tom & Jerry"));
        QCOMPARE(menuLabelText("Rock && &Roll"), QString("Rock & Roll"));
    }
    void rowHeight()
    {
        MenuStyle style;
        QMenu menu;
        menu.setStyle(&style);
        QAction* a = menu.addAction("A");
        QAction* sep = menu.addSeparator();
        menu.addAction("B"); // QMenu hides a trailing separator
        menu.adjustSize();
        QCOMPARE(menu.actionGeometry(a).height(), 48);
        QCOMPARE(menu.actionGeometry(sep).height(), 1);
        QVERIFY(menu.width() >= 265 + 2 * MenuStyle::shadowMargin());
    }
    void rowHeightScales()
    {
        MenuStyle::setScale(1.5);
        const auto reset = qScopeGuard([] { MenuStyle::setScale(1.0); });
        MenuStyle style;
        QMenu menu;
        menu.setStyle(&style);
        QAction* a = menu.addAction("A");
        menu.adjustSize();
        QCOMPARE(menu.actionGeometry(a).height(), 72);
    }
    // SortMenu / QmlMenuPositioner pop a menu up above a point: the card, not the window, ends on it
    void popupAboveLandsOnAnchor()
    {
        MenuStyle::install(); // the app's way: menus get polished by the application style
        QMenu menu;
        menu.addAction("A");
        menu.addAction("B");
        const QPoint anchor(200, 400);
        menu.popup(QPoint(anchor.x(), anchor.y() - MenuStyle::cardHeight(&menu, menu.sizeHint().height())));
        const QMargins m = menu.contentsMargins();
        QVERIFY(!m.isNull());
        const QRect card = menu.geometry().marginsRemoved(m);
        QCOMPARE(card.left(), anchor.x());
        QCOMPARE(card.bottom() + 1, anchor.y());
        menu.hide();
    }
    // QMenu::addSection (the bookmark and program menus): a 48 px header row, not a 1 px line
    void sectionHeader()
    {
        MenuStyle style;
        QMenu menu;
        menu.setStyle(&style);
        QAction* section = menu.addSection("Chapters");
        menu.addAction("A");
        menu.adjustSize();
        QCOMPARE(menu.actionGeometry(section).height(), 48);
    }
    // a torn-off menu is a QMenu in a normal window: it keeps its frame
    void tornOffKeepsFrame()
    {
        MenuStyle::install();
        QMenu menu;
        menu.setTearOffEnabled(true);
        menu.addAction("A");
        menu.showTearOffMenu(QPoint(10, 10));
        QMenu* torn = nullptr;
        for (QWidget* w : QApplication::topLevelWidgets())
            if (auto m = qobject_cast<QMenu*>(w); m && m != &menu && m->isVisible())
                torn = m;
        QVERIFY(torn);
        QVERIFY(!(torn->windowFlags() & Qt::FramelessWindowHint));
        QVERIFY(torn->contentsMargins().isNull());
        menu.hideTearOffMenu();
    }
    // the key only shows: skins2's sendKey triggers any popup action whose shortcut() matches
    void showKeyIsDisplayOnly()
    {
        QMenu menu;
        QAction* a = menu.addAction("&Record");
        menuShowKey(a, QKeySequence("Shift+R"));
        QVERIFY(a->shortcut().isEmpty());
        const QStringList parts = a->text().split(u'\t');
        QCOMPARE(parts.size(), 2);
        QCOMPARE(parts[0], QString("&Record"));
        // what the style draws in the shortcut column
        QCOMPARE(menuShortcutText(QKeySequence::fromString(parts[1], QKeySequence::NativeText)),
                 QString("Shift + R"));
    }
    // native menus from QML: strings and { text, icon, separator, checked, enabled }
    void menuRows()
    {
        QMenu menu;
        QList<int> fired;
        addMenuRows(&menu, { "A", QVariantMap{{"separator", true}},
                             QVariantMap{{"text", "B"}, {"icon", "play"}, {"enabled", false}},
                             QVariantMap{{"text", "Tom && Jerry"}} },
                    [&](int i) { fired << i; });
        const QList<QAction*> actions = menu.actions();
        QCOMPARE(actions.size(), 4);
        QVERIFY(actions[1]->isSeparator());
        QVERIFY(!actions[2]->isEnabled());
        QVERIFY(!actions[2]->icon().isNull());
        QCOMPARE(actions[3]->text(), QString("Tom && Jerry"));
        actions[3]->trigger();
        actions[0]->trigger();
        QCOMPARE(fired, QList<int>({3, 0}));
    }
};

QTEST_MAIN(TestMenuStyle)
#include "test_menu_style.moc"
