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
#ifndef VLC_FIGMATOKENS_HPP
#define VLC_FIGMATOKENS_HPP

#include <QObject>
#include <QColor>

struct vlc_qt_theme_provider_t;

// The Figma's Dark/* and Light/* paint styles: the only place a token's hex is written.
// QML reads them as theme.palette.tokens.<name>.
struct FigmaTokens
{
    Q_GADGET
    Q_PROPERTY(QColor fg1 MEMBER fg1)
    Q_PROPERTY(QColor fg2 MEMBER fg2)
    Q_PROPERTY(QColor fgA1 MEMBER fgA1)
    Q_PROPERTY(QColor fgA2 MEMBER fgA2)
    Q_PROPERTY(QColor fgA3 MEMBER fgA3)
    Q_PROPERTY(QColor fgA4 MEMBER fgA4)
    Q_PROPERTY(QColor fgB1 MEMBER fgB1)
    Q_PROPERTY(QColor bgA1 MEMBER bgA1)
    Q_PROPERTY(QColor bgA2 MEMBER bgA2)
    Q_PROPERTY(QColor bgA3 MEMBER bgA3)
    Q_PROPERTY(QColor bgA4 MEMBER bgA4)
    Q_PROPERTY(QColor bgA5 MEMBER bgA5)
    Q_PROPERTY(QColor bgB1 MEMBER bgB1)
    Q_PROPERTY(QColor bgB2 MEMBER bgB2)
    Q_PROPERTY(QColor bgA3Transparent MEMBER bgA3Transparent)
    Q_PROPERTY(QColor bgB1Transparent MEMBER bgB1Transparent)
    Q_PROPERTY(QColor bgB2Transparent MEMBER bgB2Transparent)
    Q_PROPERTY(QColor dividerDim MEMBER dividerDim)
    Q_PROPERTY(QColor dividerBright MEMBER dividerBright)
    Q_PROPERTY(QColor accent MEMBER accent)
    Q_PROPERTY(QColor accentBright MEMBER accentBright)
    Q_PROPERTY(QColor accentDim MEMBER accentDim)
    Q_PROPERTY(QColor logo MEMBER logo)
    Q_PROPERTY(QColor accentBgBright MEMBER accentBgBright)
    Q_PROPERTY(QColor accentBgDark MEMBER accentBgDark)
public:
    QColor fg1, fg2, fgA1, fgA2, fgA3, fgA4, fgB1;
    QColor bgA1, bgA2, bgA3, bgA4, bgA5, bgB1, bgB2;
    QColor bgA3Transparent, bgB1Transparent, bgB2Transparent;
    QColor dividerDim, dividerBright;
    QColor accent, accentBright, accentDim, logo, accentBgBright, accentBgDark;
};

// The table for one theme. The accent tokens derive from `accent`; with `defaultAccent`
// they are the Figma's own values for its orange (accent, logo, BG/Accent Bright and Dark).
FigmaTokens figmaTokens(bool dark, const QColor& accent, bool defaultAccent);

// A colour that is no token: the light value of the dark grey token nearest in lightness,
// with the colour's alpha (the spec's rule for off-token literals).
QColor lightPartner(const QColor& darkColour);

// System's choice: the provider's dark preference. No provider, or one that
// reports nothing, is Light.
bool systemIsDark(vlc_qt_theme_provider_t* providerOrNull);

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
// System's choice with Qt's colour-scheme hint: a provider that answers decides (the GTK one reads the
// desktop portal's color-scheme); without one the hint does (macOS). Qt's GTK 3 theme can start with a
// stale Light hint while GNOME prefers dark, so the hint doesn't outrank the provider.
bool systemIsDark(Qt::ColorScheme hint, vlc_qt_theme_provider_t* providerOrNull);
#endif

#endif // VLC_FIGMATOKENS_HPP
