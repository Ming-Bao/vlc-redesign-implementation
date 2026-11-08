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

#include <vlc_common.h>
#include <vlc_fourcc.h>
#include <vlc_image.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_preparser.h>

#include <QPainter>
#include <QPainterPath>

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
    if (m_current)
        vlc_preparser_Cancel(m_preparser, m_current);
    m_current = nullptr;
    m_latest.reset();
    setFrame(QImage());
    emit uriChanged();
}

void SeekPreview::setPosition(double position)
{
    if (position == m_position)
        return;
    m_position = position;
    emit positionChanged();
    if (m_latest.request(seekpreview::clampPosition(position)))
        submit(seekpreview::clampPosition(position));
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
    vlc_preparser_req* req = nullptr;
    if (m_ctx && !m_uri.isEmpty())
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
        return; // cancelled by a uri change
    m_current = nullptr;
    if (!image.isNull())
        setFrame(image);
    if (auto next = m_latest.finished())
        submit(*next);
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
