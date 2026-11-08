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
#ifndef VLC_QT_SEEK_PREVIEW_HPP
#define VLC_QT_SEEK_PREVIEW_HPP

#include <QImage>
#include <QList>
#include <QQuickPaintedItem>
#include <QUrl>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"
#include "seek_preview_util.hpp"

typedef struct vlc_preparser_t vlc_preparser_t;
typedef struct vlc_preparser_req vlc_preparser_req;
typedef struct image_handler_t image_handler_t;

// one frame of `uri` at `position`, asked of the core thumbnailer (QML type "SeekPreview")
class SeekPreview : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QUrl uri READ uri WRITE setUri NOTIFY uriChanged FINAL)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged FINAL)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged FINAL)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged FINAL)

public:
    explicit SeekPreview(QQuickItem* parent = nullptr);
    ~SeekPreview() override;

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QUrl uri() const { return m_uri; }
    void setUri(const QUrl& uri);
    double position() const { return m_position; }
    void setPosition(double position);
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);
    bool hasFrame() const { return !m_frame.isNull(); }

    Q_INVOKABLE bool allowed() const;

    void paint(QPainter* painter) override;

protected:
    void itemChange(ItemChange change, const ItemChangeData& value) override;

signals:
    void ctxChanged();
    void uriChanged();
    void positionChanged();
    void radiusChanged();
    void hasFrameChanged();

private:
    static void onEnded(vlc_preparser_req* req, int status, picture_t* thumbnail, void* data);
    void requestShown();
    void submit(double position);
    void finish(vlc_preparser_req* req, const QImage& image);
    void setFrame(const QImage& frame);

    MainCtx* m_ctx = nullptr;
    QUrl m_uri;
    double m_position = 0.;
    qreal m_radius = 0.;
    QImage m_frame;
    seekpreview::LatestOnly m_latest;
    vlc_preparser_t* m_preparser = nullptr;
    vlc_object_t* m_obj = nullptr;            // set with m_preparser, read by onEnded
    vlc_preparser_req* m_current = nullptr;   // the request whose result is wanted
    QList<vlc_preparser_req*> m_inflight;     // submitted, result not yet back on the Qt thread
    image_handler_t* m_image = nullptr;       // thumbnailer thread only (1 thread)
};

#endif
