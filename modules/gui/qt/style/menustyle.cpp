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
#include "menustyle.hpp"
#include "vlcicons.hpp"

#include <QApplication>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QScreen>
#include <QStyleOption>
#include <algorithm>
#include <cmath>

namespace {

qreal s_scale = 1.0;

int dp(qreal px) { return qRound(px * s_scale); }

// Figma menu frames (6062:13354 and siblings), logical px
// ponytail: dark values only; read the palette's lightness in slice 10 (light theme)
const QColor cardColor(25, 25, 25, qRound(0.95 * 255));
const QColor highlightColor(0x1F, 0x1F, 0x1F);
const QColor labelColor(0x8F, 0x8F, 0x8F);
const QColor shortcutColor(0x6B, 0x6B, 0x6B);
const QColor dividerColor(0x22, 0x22, 0x22);
const QColor checkColor(0xD3, 0x79, 0x18);
const QColor chevronColor(0x8F, 0x8F, 0x8F);
constexpr qreal shadowBlur = 15, shadowYOffset = 8, shadowAlpha = 0.46;
constexpr qreal cardRadius = 10, cardPadding = 4;
constexpr qreal rowHeight = 48, rowHPadding = 14, rowVPadding = 2, rowSpacing = 10, rowRadius = 6;
constexpr qreal iconSize = 24, fontSize = 14, minWidth = 265;

const QMenu* asMenu(const QWidget* w) { return qobject_cast<const QMenu*>(w); }

// the shadow sits 8 px lower than the card, so it needs less room above than below
QMargins shadowMargins()
{
    const int m = MenuStyle::shadowMargin(), y = dp(shadowYOffset);
    return { m, m - y, m, m + y };
}

QFont menuFont(const QWidget* w)
{
    QFont f = w->font();
    f.setPixelSize(dp(fontSize));
    return f;
}

std::pair<QString, QString> splitText(const QString& text)
{
    const qsizetype tab = text.indexOf(u'\t');
    if (tab < 0)
        return { text, {} };
    return { text.left(tab), text.mid(tab + 1) };
}

QString shortcutColumn(const QString& native)
{
    const QKeySequence seq = QKeySequence::fromString(native, QKeySequence::NativeText);
    return seq.isEmpty() ? native : menuShortcutText(seq);
}

bool hasIconSlot(const QStyleOptionMenuItem* mi)
{
    return mi->maxIconWidth > 0 || mi->menuHasCheckableItems;
}

bool hasChevron(const QAction* a)
{
    return a && (a->menu() || a->property("vlc-chevron").toBool());
}

bool anyChevron(const QMenu* menu)
{
    const auto actions = menu->actions();
    return std::any_of(actions.begin(), actions.end(),
                       [](const QAction* a) { return a->isVisible() && hasChevron(a); });
}

void drawGlyph(QPainter* p, const QRect& r, QChar glyph, const QColor& color)
{
    QFont f(VLCIcons::fontFamily);
    f.setPixelSize(r.height());
    p->setFont(f);
    p->setPen(color);
    p->drawText(r, Qt::AlignCenter, QString(glyph));
}

} // namespace

QString menuShortcutText(const QKeySequence& seq)
{
    QStringList combos;
    for (int i = 0; i < seq.count(); ++i)
    {
        const QKeyCombination combo = seq[i];
        const QString key = QKeySequence(combo.key()).toString(QKeySequence::NativeText);
        const QString all = QKeySequence(combo).toString(QKeySequence::NativeText);
        // modifiers are what precedes the key: "Ctrl+Shift+" (the key itself may be "+")
        QStringList parts = all.left(all.size() - key.size()).split(u'+', Qt::SkipEmptyParts);
        parts << key;
        combos << parts.join(QStringLiteral(" + "));
    }
    return combos.join(QStringLiteral(", "));
}

QString menuLabelText(const QString& text)
{
    QString out;
    out.reserve(text.size());
    for (qsizetype i = 0; i < text.size(); ++i)
    {
        if (text[i] == u'&' && ++i == text.size())
            break;
        out += text[i];
    }
    return out;
}

MenuStyle::MenuStyle(QStyle* base) : QProxyStyle(base) {}

void MenuStyle::install()
{
    if (!dynamic_cast<MenuStyle*>(QApplication::style()))
        QApplication::setStyle(new MenuStyle(QApplication::style()));
}

void MenuStyle::setScale(qreal scale) { s_scale = scale; }

int MenuStyle::shadowMargin() { return dp(shadowBlur); }

int MenuStyle::cardHeight(const QWidget* menu, int windowHeight)
{
    const QMargins m = menu->contentsMargins();
    return windowHeight - m.top() - m.bottom();
}

void MenuStyle::polish(QWidget* w)
{
    QProxyStyle::polish(w);
    auto menu = qobject_cast<QMenu*>(w);
    if (!menu)
        return;
    menu->setAttribute(Qt::WA_TranslucentBackground);
    menu->setWindowFlags(menu->windowFlags() | Qt::FramelessWindowHint | Qt::NoDropShadowWindowHint);
    const QMargins m = shadowMargins();
    menu->setContentsMargins(m);
    menu->setMinimumWidth(dp(minWidth) + m.left() + m.right());
    menu->installEventFilter(this);
}

void MenuStyle::unpolish(QWidget* w)
{
    if (auto menu = qobject_cast<QMenu*>(w))
    {
        menu->removeEventFilter(this);
        menu->setMinimumWidth(0);
        menu->setContentsMargins({});
        menu->setWindowFlags(menu->windowFlags() & ~(Qt::FramelessWindowHint | Qt::NoDropShadowWindowHint));
        menu->setAttribute(Qt::WA_TranslucentBackground, false);
    }
    QProxyStyle::unpolish(w);
}

void MenuStyle::drawPrimitive(PrimitiveElement pe, const QStyleOption* opt, QPainter* p,
                              const QWidget* w) const
{
    const QMenu* menu = asMenu(w);
    if (menu && pe == PE_FrameMenu)
        return;
    if (!menu || pe != PE_PanelMenu)
        return QProxyStyle::drawPrimitive(pe, opt, p, w);

    const QRectF card = QRectF(menu->rect()).marginsRemoved(menu->contentsMargins());
    p->save();
    p->setRenderHint(QPainter::Antialiasing);
    p->setPen(Qt::NoPen);

    // Figma: shadow 0 8 15 rgba(0,0,0,0.46). A stack of growing translucent rounded rects
    // ramps it from full under the card to nothing outside it.
    // ponytail: linear ramp, not a true gaussian; blur an image if it ever shows
    const int ramp = std::max(1, dp(shadowBlur * 0.6));
    const int layers = 2 * ramp + 1;
    p->setBrush(QColor(0, 0, 0, qRound(255 * (1 - std::pow(1 - shadowAlpha, 1.0 / layers)))));
    const QRectF shadow = card.translated(0, dp(shadowYOffset));
    const qreal radius = dp(cardRadius);
    for (int e = -ramp; e <= ramp; ++e)
    {
        const qreal r = std::max<qreal>(0, radius + e);
        p->drawRoundedRect(shadow.adjusted(-e, -e, e, e), r, r);
    }

    p->setBrush(cardColor);
    p->drawRoundedRect(card, radius, radius);
    p->restore();
}

void MenuStyle::drawControl(ControlElement ce, const QStyleOption* opt, QPainter* p,
                            const QWidget* w) const
{
    const QMenu* menu = asMenu(w);
    if (menu && ce == CE_MenuEmptyArea)
        return;
    const auto mi = qstyleoption_cast<const QStyleOptionMenuItem*>(opt);
    if (!menu || !mi || ce != CE_MenuItem)
        return QProxyStyle::drawControl(ce, opt, p, w);

    // ponytail: left-to-right only; mirror the slots with QStyle::visualRect if RTL menus need it
    const QRect r = mi->rect;
    p->save();
    if (mi->menuItemType == QStyleOptionMenuItem::Separator)
    {
        p->fillRect(QRect(r.left(), r.top() + r.height() / 2, r.width(), 1), dividerColor);
        p->restore();
        return;
    }

    const bool enabled = mi->state & State_Enabled;
    p->setRenderHint(QPainter::Antialiasing);
    if (enabled && (mi->state & State_Selected))
    {
        p->setPen(Qt::NoPen);
        p->setBrush(highlightColor);
        p->drawRoundedRect(r, dp(rowRadius), dp(rowRadius));
    }
    p->setOpacity(enabled ? 1 : 0.4);

    const QRect c = r.adjusted(dp(rowHPadding), dp(rowVPadding), -dp(rowHPadding), -dp(rowVPadding));
    const int icon = dp(iconSize), gap = dp(rowSpacing);
    int left = c.left(), right = c.right() + 1;

    if (hasIconSlot(mi))
    {
        const QRect slot(left, c.top() + (c.height() - icon) / 2, icon, icon);
        if (mi->checkType != QStyleOptionMenuItem::NotCheckable && mi->checked)
            drawGlyph(p, slot, VLCIcons::checkmark, checkColor);
        else if (!mi->icon.isNull())
            mi->icon.paint(p, slot);
        left += icon + gap;
    }

    if (mi->menuItemType == QStyleOptionMenuItem::SubMenu || hasChevron(menu->actionAt(r.center())))
    {
        right -= icon;
        drawGlyph(p, QRect(right, c.top() + (c.height() - icon) / 2, icon, icon),
                  VLCIcons::ic_fluent_chevron_right_24, chevronColor);
        right -= gap;
    }

    const QFont font = menuFont(menu);
    const QFontMetrics fm(font);
    p->setFont(font);
    const auto [label, native] = splitText(mi->text);
    if (!native.isEmpty())
    {
        const QString shortcut = shortcutColumn(native);
        p->setPen(shortcutColor);
        p->drawText(QRect(left, c.top(), right - left, c.height()), Qt::AlignRight | Qt::AlignVCenter, shortcut);
        right -= fm.horizontalAdvance(shortcut) + gap;
    }

    p->setPen(labelColor);
    p->drawText(QRect(left, c.top(), right - left, c.height()), Qt::AlignLeft | Qt::AlignVCenter,
                fm.elidedText(menuLabelText(label), Qt::ElideRight, right - left));
    p->restore();
}

QSize MenuStyle::sizeFromContents(ContentsType ct, const QStyleOption* opt, const QSize& size,
                                  const QWidget* w) const
{
    const QMenu* menu = asMenu(w);
    const auto mi = qstyleoption_cast<const QStyleOptionMenuItem*>(opt);
    if (!menu || !mi || ct != CT_MenuItem)
        return QProxyStyle::sizeFromContents(ct, opt, size, w);

    if (mi->menuItemType == QStyleOptionMenuItem::Separator)
        return { 1, 1 };

    const QFontMetrics fm(menuFont(menu));
    const auto [label, native] = splitText(mi->text);
    int width = 2 * dp(rowHPadding) + fm.horizontalAdvance(menuLabelText(label));
    if (hasIconSlot(mi))
        width += dp(iconSize) + dp(rowSpacing);
    // QMenu adds its own column for the shortcut as Qt writes it ("Ctrl+O"); add the difference
    if (!native.isEmpty())
        width += dp(rowSpacing) + fm.horizontalAdvance(shortcutColumn(native))
                 - menu->fontMetrics().horizontalAdvance(native);
    if (anyChevron(menu))
        width += dp(iconSize) + dp(rowSpacing);
    return { width, dp(rowHeight) };
}

int MenuStyle::pixelMetric(PixelMetric pm, const QStyleOption* opt, const QWidget* w) const
{
    if (asMenu(w))
    {
        switch (pm)
        {
        case PM_MenuPanelWidth:
            return 0;
        case PM_MenuHMargin:
        case PM_MenuVMargin:
            return dp(cardPadding);
        case PM_SmallIconSize:
            return dp(iconSize);
        // Figma Profiles frame: the submenu card sits 12 px right of its parent's
        case PM_SubMenuOverlap:
            return dp(12 + cardPadding);
        default:
            break;
        }
    }
    return QProxyStyle::pixelMetric(pm, opt, w);
}

int MenuStyle::styleHint(StyleHint sh, const QStyleOption* opt, const QWidget* w,
                         QStyleHintReturn* ret) const
{
    if (asMenu(w) && (sh == SH_UnderlineShortcut || sh == SH_Menu_Mask))
        return 0;
    return QProxyStyle::styleHint(sh, opt, w, ret);
}

bool MenuStyle::eventFilter(QObject* obj, QEvent* ev)
{
    // QMenu placed the window at the requested point; put the card there instead
    if (ev->type() == QEvent::Show)
    {
        if (auto menu = qobject_cast<QMenu*>(obj))
        {
            const QMargins m = menu->contentsMargins();
            QPoint to = menu->pos() - QPoint(m.left(), m.top());
            // a submenu (its parent menu is still the active popup): line its rows up with the parent row
            if (qobject_cast<QMenu*>(QApplication::activePopupWidget()))
                to.ry() -= dp(cardPadding);
            const QRect card = menu->rect().marginsRemoved(m).translated(to);
            const QScreen* screen = QGuiApplication::screenAt(card.center());
            if (!screen)
                screen = menu->screen();
            if (screen && screen->availableGeometry().contains(card))
                menu->move(to);
        }
    }
    return QProxyStyle::eventFilter(obj, ev);
}
