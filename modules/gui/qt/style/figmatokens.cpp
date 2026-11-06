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
#include "figmatokens.hpp"
#include "qtthemeprovider.hpp"

#include <iterator>

namespace {

QColor withAlpha(const char* hex, double alpha)
{
    QColor c(hex);
    c.setAlpha(qRound(alpha * 255));
    return c;
}

// `top` at `alpha` over `base`, computed as QML's Qt.rgba() does
QColor over(const QColor& top, double alpha, const QColor& base)
{
    return QColor::fromRgbF(top.redF() * alpha + base.redF() * (1 - alpha),
                            top.greenF() * alpha + base.greenF() * (1 - alpha),
                            top.blueF() * alpha + base.blueF() * (1 - alpha));
}

// the grey tokens lightPartner() picks from; backgrounds first, so #222222 is BG/A1, not Divider/Dim.
// FG/A3 and FG/B1 are left out: they are the same in both themes, so a dark surface near them
// (#171717 is a card backing) would stay dark in light.
constexpr QColor FigmaTokens::* greys[] = {
    &FigmaTokens::bgA1, &FigmaTokens::bgA2, &FigmaTokens::bgA3, &FigmaTokens::bgA4,
    &FigmaTokens::bgA5, &FigmaTokens::bgB1, &FigmaTokens::bgB2,
    &FigmaTokens::fg1, &FigmaTokens::fg2, &FigmaTokens::fgA1, &FigmaTokens::fgA2, &FigmaTokens::fgA4,
    &FigmaTokens::dividerDim, &FigmaTokens::dividerBright,
};

} // namespace

FigmaTokens figmaTokens(bool dark, const QColor& accent, bool defaultAccent)
{
    FigmaTokens t;
    // token: Dark, Light used (the spec's token table, last column; empty there = the Figma's light)
#define TOKEN(name, darkHex, lightHex) t.name = QColor(dark ? darkHex : lightHex)
    TOKEN(fg1,  "#EAEAEA", "#161616");   // light: my call, the Figma's is the dark value
    TOKEN(fg2,  "#C6C6C6", "#2E2E2E");   // light: my call, the Figma's is the dark value
    TOKEN(fgA1, "#969696", "#3C3C3C");
    TOKEN(fgA2, "#8F8F8F", "#2E2E2E");
    TOKEN(fgA4, "#404040", "#9B9B9B");   // light: my call, the Figma's #3B3B3B outranks FG/A3
    TOKEN(bgA1, "#222222", "#EDEDED");
    TOKEN(bgA2, "#1F1F1F", "#DDDDDD");
    TOKEN(bgA3, "#1B1B1B", "#D5D5D5");
    TOKEN(bgA4, "#191919", "#D5D5D5");   // light: my call (= light BG/A3), the Figma's is #B3B3B3
    TOKEN(bgA5, "#151515", "#DEDEDE");   // light: my call (= light BG/B2), the Figma's is #888888
    TOKEN(bgB1, "#0E0E0E", "#E7E7E7");
    TOKEN(bgB2, "#090909", "#DEDEDE");
    TOKEN(dividerDim,    "#222222", "#ACACAC");
    TOKEN(dividerBright, "#373737", "#9B9B9B");
#undef TOKEN
    t.fgA3 = QColor("#6B6B6B");   // the same in both themes
    t.fgB1 = QColor("#161616");
    t.bgA3Transparent = dark ? withAlpha("#191919", 0.95) : withAlpha("#D5D5D5", 0.75);
    t.bgB1Transparent = dark ? withAlpha("#0E0E0E", 0.95) : withAlpha("#E7E7E7", 0.80);
    t.bgB2Transparent = withAlpha("#000000", 0.80);   // light: my call, it dims behind dialogs

    if (defaultAccent)
    {
        t.accent         = QColor(dark ? "#D37918" : "#E8851A");
        t.accentBright   = QColor(dark ? "#FC9729" : "#FFA13B");
        t.logo           = QColor(dark ? "#D37918" : "#C2711A");
        t.accentBgBright = QColor(dark ? "#371F06" : "#D8BA9A");
        t.accentBgDark   = QColor(dark ? "#1A1611" : "#C6AB89");
    }
    else
    {
        // my call: these reproduce the Figma's values from its default orange
        t.accent         = accent;
        t.accentBright   = accent.lighter(125);
        t.logo           = accent;
        t.accentBgBright = dark ? over(accent, 0.26, Qt::black) : over(accent, 0.30, QColor("#D1D1D1"));
        t.accentBgDark   = dark ? over(accent, 0.05, QColor("#111111")) : over(accent, 0.30, QColor("#B9B9B9"));
    }
    // always derived: dark QML has drawn Qt.darker(accent, 1.24) since slice 4
    t.accentDim = t.accent.darker(dark ? 124 : 155);
    t.accentText = dark ? t.accent : t.accentDim;
    return t;
}

QColor lightPartner(const QColor& darkColour)
{
    static const FigmaTokens d = figmaTokens(true, {}, true), l = figmaTokens(false, {}, true);
    auto nearest = std::begin(greys);
    for (auto g = std::begin(greys); g != std::end(greys); ++g)
        if (qAbs((d.*(*g)).lightness() - darkColour.lightness()) < qAbs((d.*(*nearest)).lightness() - darkColour.lightness()))
            nearest = g;
    QColor c = l.*(*nearest);
    c.setAlphaF(darkColour.alphaF());
    return c;
}

bool systemIsDark(vlc_qt_theme_provider_t* provider)
{
    return provider && provider->isThemeDark && provider->isThemeDark(provider);
}

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
bool systemIsDark(Qt::ColorScheme hint, vlc_qt_theme_provider_t* provider)
{
    if (provider && provider->isThemeDark)
        return provider->isThemeDark(provider);
    return hint == Qt::ColorScheme::Dark;
}
#endif
