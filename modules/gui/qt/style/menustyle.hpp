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
#ifndef VLC_QT_MENUSTYLE_HPP
#define VLC_QT_MENUSTYLE_HPP

#include <QProxyStyle>
#include <QKeySequence>

/// "Ctrl+Shift+O" -> "Ctrl + Shift + O" (Figma's shortcut column)
QString menuShortcutText(const QKeySequence& seq);
/// drops the mnemonic markers: "Open &File" -> "Open File", "Tom && Jerry" -> "Tom & Jerry"
QString menuLabelText(const QString& text);

/// Draws every QMenu the redesign way (Figma menu frames), on top of whatever style is chosen.
/// An action with the bool property "vlc-chevron" gets a chevron without being a submenu.
class MenuStyle : public QProxyStyle
{
public:
    explicit MenuStyle(QStyle* base = nullptr);

    /// wraps QApplication::style() unless it already is a MenuStyle
    static void install();
    /// the interface scale factor (MainCtx::getIntfScaleFactor())
    static void setScale(qreal scale);
    /// transparent margin around the card that holds its shadow, scaled
    static int shadowMargin();

    void polish(QWidget* widget) override;
    void unpolish(QWidget* widget) override;
    using QProxyStyle::polish;
    using QProxyStyle::unpolish;

    void drawPrimitive(PrimitiveElement pe, const QStyleOption* opt, QPainter* p,
                       const QWidget* w = nullptr) const override;
    void drawControl(ControlElement ce, const QStyleOption* opt, QPainter* p,
                     const QWidget* w = nullptr) const override;
    QSize sizeFromContents(ContentsType ct, const QStyleOption* opt, const QSize& size,
                           const QWidget* w = nullptr) const override;
    int pixelMetric(PixelMetric pm, const QStyleOption* opt = nullptr,
                    const QWidget* w = nullptr) const override;
    int styleHint(StyleHint sh, const QStyleOption* opt = nullptr, const QWidget* w = nullptr,
                  QStyleHintReturn* ret = nullptr) const override;

protected:
    bool eventFilter(QObject* obj, QEvent* ev) override;
};

#endif // VLC_QT_MENUSTYLE_HPP
