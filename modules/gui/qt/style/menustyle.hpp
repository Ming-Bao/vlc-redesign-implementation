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

#include <QIcon>
#include <QProxyStyle>
#include <QKeySequence>
#include <QVariantList>
#include <functional>

class QAction;
class QMenu;

/// "Ctrl+Shift+O" -> "Ctrl + Shift + O" (Figma's shortcut column)
QString menuShortcutText(const QKeySequence& seq);
/// drops the mnemonic markers: "Open &File" -> "Open File", "Tom && Jerry" -> "Tom & Jerry"
QString menuLabelText(const QString& text);

/// the redesign's menu icon ":/redesign/menu/<name>.svg"
QIcon menuIcon(const QString& name);

/// Adds one action per row: a row is a string or a map { text, icon (a ":/redesign/menu/" name),
/// separator, checked, enabled }. onSelected gets the row's index in rows
/// (separators count, they never fire). Lives here so the menu style test can link it.
void addMenuRows(QMenu* menu, const QVariantList& rows, std::function<void(int)> onSelected);

/// Shows key in the action's shortcut column without binding it (the text after '\t'):
/// VLC's own hotkey does the work, and skins2's DialogsProvider::sendKey triggers any action
/// whose shortcut() matches.
void menuShowKey(QAction* action, const QKeySequence& key);

/// Draws every QMenu the redesign way (Figma menu frames), on top of whatever style is chosen.
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
    /// height of the card in a menu window of the given height, i.e. without the shadow margins.
    /// A menu popped up above a point subtracts this, so the card (not the window) ends on the point.
    static int cardHeight(const QWidget* menu, int windowHeight);

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
