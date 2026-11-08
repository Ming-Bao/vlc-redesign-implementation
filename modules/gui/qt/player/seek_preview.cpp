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

#include "seek_preview.hpp"
#include "player/player_controller.hpp"

#include <vlc_common.h>
#include <vlc_fourcc.h>
#include <vlc_image.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_player.h>
#include <vlc_preparser.h>

#include <QPainter>
#include <QPainterPath>

static_assert(ORIENT_TOP_RIGHT == 1 && ORIENT_BOTTOM_RIGHT == 3 && ORIENT_LEFT_TOP == 4
              && ORIENT_LEFT_BOTTOM == 5 && ORIENT_RIGHT_TOP == 6 && ORIENT_RIGHT_BOTTOM == 7,
              "seekpreview::oriented() uses the vlc_es.h numbering");

namespace
{
// largest frame the card shows
const QSize MAX_FRAME(504, 284);
}

SeekPreview::SeekPreview(QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
}

SeekPreview::~SeekPreview()
{
    // cancels and joins: every on_ended has run, their queued results die with `this`
    if (m_preparser)
        vlc_preparser_Delete(m_preparser);
    for (vlc_preparser_req* req : m_inflight)
        vlc_preparser_req_Release(req);
    if (m_image)
        image_HandlerDelete(m_image);
}

void SeekPreview::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

void SeekPreview::setUri(const QUrl& uri)
{
    if (uri == m_uri)
        return;
    m_uri = uri;
    cancel();
    setFrame(QImage());
    emit uriChanged();
    requestShown(); // a new file under a still pointer
}

void SeekPreview::setPosition(double position)
{
    if (position == m_position)
        return;
    m_position = position;
    emit positionChanged();
    requestShown();
}

// the decoded picture's format never carries the orientation (picture_Setup resets it), so take
// it from the player's video track when `m_uri` is what plays (it is: QML binds Player.url)
int SeekPreview::playingOrientation() const
{
    int orientation = ORIENT_NORMAL;
    vlc_player_t* player = m_ctx->getIntf()->p_mainPlayerController->getPlayer();
    vlc_player_Lock(player);
    input_item_t* media = vlc_player_GetCurrentMedia(player);
    if (media && media->psz_uri && QUrl(QString::fromUtf8(media->psz_uri)) == m_uri  /* as PlayerController::url */)
        if (const vlc_player_track* track = vlc_player_GetSelectedTrack(player, VIDEO_ES))
            orientation = track->fmt.video.orientation;
    vlc_player_Unlock(player);
    return orientation;
}

// drops the wanted request and anything pending; a late result is ignored by finish()
void SeekPreview::cancel()
{
    if (m_current)
        vlc_preparser_Cancel(m_preparser, m_current);
    m_current = nullptr;
    m_latest.reset();
}

// only while shown: a hidden card (audio, dragging, setting off) decodes nothing
void SeekPreview::requestShown()
{
    if (!isComponentComplete() || !isVisible())
        return;
    const double p = seekpreview::clampPosition(m_position);
    if (m_latest.request(p))
        submit(p);
}

// an item created already visible gets no ItemVisibleHasChanged, and setUri/setPosition ran too early
void SeekPreview::componentComplete()
{
    QQuickPaintedItem::componentComplete();
    requestShown();
}

void SeekPreview::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickPaintedItem::itemChange(change, value);
    if (change != ItemVisibleHasChanged)
        return;
    // positions set while hidden were not asked for: ask on show; on hide stop
    // decoding but keep the frame, so the next show is never blank
    if (value.boolValue)
        requestShown();
    else
        cancel();
}

void SeekPreview::setRadius(qreal radius)
{
    if (radius == m_radius)
        return;
    m_radius = radius;
    emit radiusChanged();
    update();
}

bool SeekPreview::allowed() const
{
    return m_ctx && var_InheritBool(m_ctx->getIntf(), "qt-seek-thumbnail")
        && seekpreview::previewableScheme(m_uri.scheme());
}

void SeekPreview::submit(double position)
{
    // no disc spin-up, and nothing when the setting is off, whatever QML does
    if (!allowed())
    {
        m_latest.reset();
        return;
    }
    vlc_preparser_req* req = nullptr;
    if (!m_uri.isEmpty())
    {
        vlc_object_t* obj = VLC_OBJECT(m_ctx->getIntf());
        if (!m_preparser)
        {
            struct vlc_preparser_cfg cfg{};
            cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
            cfg.max_thumbnailer_threads = 1;
            cfg.timeout = VLC_TICK_FROM_SEC(2);
            cfg.external_process = false;
            m_obj = obj;
            m_preparser = vlc_preparser_New(obj, &cfg);
        }
        input_item_t* item = m_preparser
            ? input_item_New(m_uri.toString(QUrl::FullyEncoded).toUtf8().constData(), nullptr)
            : nullptr;
        if (item)
        {
            struct vlc_thumbnailer_arg arg{};
            arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
            arg.seek.pos = position;
            arg.seek.speed = var_InheritBool(obj, "input-fast-seek")
                ? vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST
                : vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_PRECISE;
            arg.hw_dec = false;
            static const struct vlc_thumbnailer_cbs cbs = { &SeekPreview::onEnded };
            req = vlc_preparser_req_NewThumbnail(m_preparser, item, &arg, &cbs, this);
            input_item_Release(item);
        }
        // on_ended may run before Submit returns, but only posts to this thread, so
        // registering after Submit is still ahead of finish()
        if (req && vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
        {
            vlc_preparser_req_Release(req);
            req = nullptr;
        }
    }
    if (!req)
    {
        // nothing will come back: don't stay busy forever
        m_latest.reset();
        return;
    }
    m_inflight.append(req);
    m_current = req;
    m_orientation = playingOrientation();
}

// thumbnailer thread
void SeekPreview::onEnded(vlc_preparser_req* req, int, picture_t* thumbnail, void* data)
{
    auto self = static_cast<SeekPreview*>(data);
    QImage image;
    if (thumbnail)
    {
        if (!self->m_image)
            self->m_image = image_HandlerCreate(self->m_obj);
        const video_format_t& in = thumbnail->format;
        const unsigned sarNum = in.i_sar_num ? in.i_sar_num : 1;
        const unsigned sarDen = in.i_sar_den ? in.i_sar_den : 1;
        const QSize fit = seekpreview::fitInto(
            QSize(int(uint64_t(in.i_visible_width) * sarNum / sarDen), int(in.i_visible_height)),
            MAX_FRAME);
        video_format_t out;
        video_format_Init(&out, VLC_CODEC_RGBA);
        out.i_width = out.i_visible_width = unsigned(fit.width());
        out.i_height = out.i_visible_height = unsigned(fit.height());
        out.i_sar_num = out.i_sar_den = 1;
        picture_t* rgba = self->m_image ? image_Convert(self->m_image, thumbnail, &in, &out) : nullptr;
        if (rgba)
        {
            image = QImage(rgba->p[0].p_pixels, int(out.i_visible_width), int(out.i_visible_height),
                           rgba->p[0].i_pitch, QImage::Format_RGBA8888).copy();
            picture_Release(rgba);
        }
        video_format_Clean(&out);
    }
    QMetaObject::invokeMethod(self, [self, req, image] { self->finish(req, image); },
                              Qt::QueuedConnection);
}

void SeekPreview::finish(vlc_preparser_req* req, const QImage& image)
{
    m_inflight.removeOne(req);
    vlc_preparser_req_Release(req);
    if (req != m_current)
        return; // cancelled (uri change or hide)
    m_current = nullptr;
    if (!image.isNull())
        setFrame(seekpreview::oriented(image, m_orientation));
    if (auto next = m_latest.finished())
    {
        if (isVisible())
            submit(*next);
        else
            m_latest.reset();
    }
}

void SeekPreview::setFrame(const QImage& frame)
{
    const bool had = hasFrame();
    m_frame = frame;
    update();
    if (had != hasFrame())
        emit hasFrameChanged();
}

void SeekPreview::paint(QPainter* painter)
{
    if (m_frame.isNull())
        return;
    const QSize fit = seekpreview::fitInto(m_frame.size(), size().toSize());
    const QRectF target((width() - fit.width()) / 2., (height() - fit.height()) / 2.,
                        fit.width(), fit.height());
    painter->setRenderHint(QPainter::SmoothPixmapTransform);
    painter->setRenderHint(QPainter::Antialiasing);
    QPainterPath clip;
    clip.addRoundedRect(QRectF(0, 0, width(), height()), m_radius, m_radius);
    painter->setClipPath(clip);
    painter->drawImage(target, m_frame);
}
