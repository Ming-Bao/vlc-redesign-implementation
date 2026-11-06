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
#include <QMetaProperty>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>

#include "style/figmatokens.hpp"
#include "style/qtthemeprovider.hpp"

// every channel within tol
static bool close(const QColor& a, const QColor& b, int tol)
{
    return qAbs(a.red() - b.red()) <= tol && qAbs(a.green() - b.green()) <= tol
        && qAbs(a.blue() - b.blue()) <= tol && qAbs(a.alpha() - b.alpha()) <= tol;
}

static bool themeDark(vlc_qt_theme_provider_t*) { return true; }

class TokenHolder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(FigmaTokens tokens READ tokens CONSTANT)
public:
    FigmaTokens tokens() const { return figmaTokens(false, QColor("#E8851A"), true); }
};

class TestFigmaTokens : public QObject
{
    Q_OBJECT
private slots:
    void darkDefault()  { auto t = figmaTokens(true, QColor("#D37918"), true);
        QCOMPARE(t.fgA2, QColor("#8F8F8F")); QCOMPARE(t.bgB1, QColor("#0E0E0E"));
        QCOMPARE(t.accentBgBright, QColor("#371F06")); QCOMPARE(t.bgA3Transparent, QColor(0x19,0x19,0x19,qRound(0.95*255))); }
    void lightDefault() { auto t = figmaTokens(false, QColor("#E8851A"), true);
        QCOMPARE(t.fg1, QColor("#161616")); QCOMPARE(t.fg2, QColor("#2E2E2E")); QCOMPARE(t.fgA1, QColor("#3C3C3C"));
        QCOMPARE(t.fgA4, QColor("#9B9B9B")); QCOMPARE(t.bgA4, QColor("#D5D5D5")); QCOMPARE(t.bgA5, QColor("#DEDEDE"));
        QCOMPARE(t.bgB1Transparent, QColor(0xE7,0xE7,0xE7,qRound(0.8*255))); QCOMPARE(t.dividerDim, QColor("#ACACAC"));
        QCOMPARE(t.accent, QColor("#E8851A")); QCOMPARE(t.logo, QColor("#C2711A")); QCOMPARE(t.accentBgBright, QColor("#D8BA9A")); }
    void lightDerived() { auto t = figmaTokens(false, QColor("#E8851A"), false);   // the formula, not the table
        QVERIFY(close(t.accentBgBright, QColor("#D8BA9A"), 3)); QVERIFY(close(t.accentDim, QColor("#965916"), 6)); }
    void darkDerived()  { auto t = figmaTokens(true, QColor("#D37918"), false);
        QVERIFY(close(t.accentBgBright, QColor("#371F06"), 1)); QVERIFY(close(t.accentDim, QColor("#AB6314"), 3)); }
    void lightGreen()   { auto t = figmaTokens(false, QColor("#19A234"), false);
        QVERIFY(t.accentBgBright.lightness() > 150); }               // Review Focus 2: no dark bar in light
    void everyTokenSet(){ for (bool d : {true, false}) { auto t = figmaTokens(d, QColor("#D37918"), true);
        for (int i = 0; i < FigmaTokens::staticMetaObject.propertyCount(); ++i)
            QVERIFY(FigmaTokens::staticMetaObject.property(i).readOnGadget(&t).value<QColor>().isValid()); } }
    void pickedAccent() { auto t = figmaTokens(false, QColor("#19A234"), false);
        QCOMPARE(t.accent, QColor("#19A234")); QCOMPARE(t.logo, QColor("#19A234")); }

    // a colour that is no token takes the light value of the nearest dark token by lightness, keeping its alpha
    void lightPartner_cases() {
        QCOMPARE(lightPartner(QColor("#303030")), QColor("#9B9B9B"));           // Divider/Bright
        QColor w(Qt::white); w.setAlphaF(0.4f);
        QColor fg1("#161616"); fg1.setAlphaF(0.4f);
        QCOMPARE(lightPartner(w), fg1);                                          // FG/1
        QVERIFY(lightPartner(QColor("#171717")).lightness() > 200);             // a card backing stays a light surface
        QCOMPARE(lightPartner(QColor("#222222")), QColor("#EDEDED"));           // BG/A1, not Divider/Dim
    }

    // Review Focus 3: no provider, or one that reports nothing, is Light
    void systemIsDark_cases() {
        QVERIFY(!systemIsDark(nullptr));
        vlc_qt_theme_provider_t p{};
        QVERIFY(!systemIsDark(&p));
        p.isThemeDark = themeDark;
        QVERIFY(systemIsDark(&p));
    }

    // theme.palette.tokens.fgA2 is a typed colour read in QML
    void qmlRead() {
        QQmlEngine engine;
        TokenHolder holder;
        engine.rootContext()->setContextProperty("holder", &holder);
        QQmlComponent c(&engine);
        c.setData("import QtQuick\nQtObject { property color c: holder.tokens.fgA2 }", QUrl());
        std::unique_ptr<QObject> o(c.create());
        QVERIFY2(o, qPrintable(c.errorString()));
        QCOMPARE(o->property("c").value<QColor>(), QColor("#2E2E2E"));
    }
};

QTEST_MAIN(TestFigmaTokens)
#include "test_figma_tokens.moc"
