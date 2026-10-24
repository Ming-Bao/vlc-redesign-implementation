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
#include <QMenu>
#include <QScopeGuard>
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
};

QTEST_MAIN(TestMenuStyle)
#include "test_menu_style.moc"
