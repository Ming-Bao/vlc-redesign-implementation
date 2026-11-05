/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "opensubtitles_client.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrlQuery>

namespace {
constexpr int TimeoutMs = 20000;
constexpr qint64 MaxSubtitleBytes = 5 * 1024 * 1024;
}

OpenSubtitlesClient::OpenSubtitlesClient(const QString& apiKey, const QUrl& baseUrl, QObject* parent)
    : QObject(parent), m_key(apiKey.trimmed()), m_base(baseUrl), m_nam(new QNetworkAccessManager(this))
{
    qRegisterMetaType<QVector<SubtitleHit>>();
}

QNetworkRequest OpenSubtitlesClient::request(const QUrl& url, bool withKey) const
{
    QNetworkRequest r(url);
    // the API asks for a descriptive User-Agent naming the application
    r.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("VLC media player (Qt interface)"));
    r.setRawHeader("Accept", "application/json");
    if (withKey)
        r.setRawHeader("Api-Key", m_key.toUtf8());
    // a redirect would carry the key somewhere else: API calls fail on one
    r.setAttribute(QNetworkRequest::RedirectPolicyAttribute, withKey ? QNetworkRequest::ManualRedirectPolicy
                                                                      : QNetworkRequest::NoLessSafeRedirectPolicy);
    r.setTransferTimeout(TimeoutMs);
    return r;
}

// never the body or the URL: only what the user can act on
QString OpenSubtitlesClient::errorFor(QNetworkReply* reply, const QByteArray&)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 401 || status == 403)
        return tr("OpenSubtitles refused the API key");
    if (status == 429)
        return tr("OpenSubtitles limit reached, try again later");
    if (status >= 400)
        return tr("OpenSubtitles answered with error %1").arg(status);
    if (reply->error() == QNetworkReply::OperationCanceledError || reply->error() == QNetworkReply::TimeoutError)
        return tr("OpenSubtitles did not answer in time");
    return tr("Could not reach OpenSubtitles");
}

void OpenSubtitlesClient::abort()
{
    for (QNetworkReply** r : {&m_search, &m_download})
        if (*r) {
            QNetworkReply* reply = *r;
            *r = nullptr;
            reply->disconnect(this);
            reply->abort();
            reply->deleteLater();
        }
}

void OpenSubtitlesClient::search(const QString& query, const QString& language)
{
    if (m_search) {
        QNetworkReply* old = m_search;
        m_search = nullptr;
        old->disconnect(this);
        old->abort();
        old->deleteLater();
    }
    // the API wants lower-case, alphabetically ordered parameters
    QUrlQuery q;
    if (!language.isEmpty())
        q.addQueryItem(QStringLiteral("languages"), language.toLower());
    q.addQueryItem(QStringLiteral("query"), query.toLower());
    QUrl url(m_base.toString() + QStringLiteral("/subtitles"));
    url.setQuery(q);

    QNetworkReply* reply = m_search = m_nam->get(request(url, true));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        m_search = nullptr;
        reply->deleteLater();
        const QByteArray body = reply->read(MaxSubtitleBytes);
        if (reply->error() != QNetworkReply::NoError)
            return emit failed(errorFor(reply, body));
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        if (!doc.isObject() || !doc.object().value(QStringLiteral("data")).isArray())
            return emit failed(tr("OpenSubtitles sent an answer VLC does not understand"));
        emit results(parseResults(body));
    });
}

void OpenSubtitlesClient::download(int fileId, const QString& destPath)
{
    if (m_download) {
        QNetworkReply* old = m_download;
        m_download = nullptr;
        old->disconnect(this);
        old->abort();
        old->deleteLater();
    }
    QNetworkRequest r = request(QUrl(m_base.toString() + QStringLiteral("/download")), true);
    r.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const QByteArray payload = QJsonDocument(QJsonObject{{QStringLiteral("file_id"), fileId}}).toJson(QJsonDocument::Compact);

    QNetworkReply* reply = m_download = m_nam->post(r, payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply, destPath] {
        reply->deleteLater();
        const QByteArray body = reply->read(MaxSubtitleBytes);
        if (reply->error() != QNetworkReply::NoError) {
            m_download = nullptr;
            return emit downloadFailed(errorFor(reply, body));
        }
        const QUrl link(QJsonDocument::fromJson(body).object().value(QStringLiteral("link")).toString());
        if (!link.isValid() || (link.scheme() != QLatin1String("https") && link.scheme() != QLatin1String("http"))) {
            m_download = nullptr;
            return emit downloadFailed(tr("OpenSubtitles sent an answer VLC does not understand"));
        }
        // the file's own host never sees the key
        QNetworkReply* file = m_download = m_nam->get(request(link, false));
        connect(file, &QNetworkReply::finished, this, [this, file, destPath] {
            m_download = nullptr;
            file->deleteLater();
            const QByteArray data = file->read(MaxSubtitleBytes + 1);
            if (file->error() != QNetworkReply::NoError)
                return emit downloadFailed(errorFor(file, data));
            if (data.isEmpty() || data.size() > MaxSubtitleBytes)
                return emit downloadFailed(tr("OpenSubtitles sent an answer VLC does not understand"));
            QSaveFile out(destPath);
            if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.commit())
                return emit downloadFailed(tr("Could not save the subtitle file"));
            emit downloaded(destPath);
        });
    });
}

QVector<SubtitleHit> OpenSubtitlesClient::parseResults(const QByteArray& json)
{
    QVector<SubtitleHit> hits;
    const QJsonArray data = QJsonDocument::fromJson(json).object().value(QStringLiteral("data")).toArray();
    for (const QJsonValue& item : data) {
        const QJsonObject attrs = item.toObject().value(QStringLiteral("attributes")).toObject();
        const QString language = attrs.value(QStringLiteral("language")).toString();
        // a result can hold several files (CDs); each is one hit
        for (const QJsonValue& f : attrs.value(QStringLiteral("files")).toArray()) {
            const QJsonObject file = f.toObject();
            const int id = file.value(QStringLiteral("file_id")).toInt();
            QString name = file.value(QStringLiteral("file_name")).toString();
            if (name.isEmpty())
                name = attrs.value(QStringLiteral("release")).toString();
            if (id > 0 && !name.isEmpty())
                hits.append({id, name, language});
        }
    }
    return hits;
}

QString OpenSubtitlesClient::subtitleFileName(const QString& mediaStem, const QString& language)
{
    static const QRegularExpression bad(QStringLiteral("[^a-z0-9-]"));
    QString lang = language.toLower();
    lang.remove(bad);
    QString stem = mediaStem;
    // no separator, control character or leading dot survives
    static const QRegularExpression badStem(QStringLiteral("[/\\\\:*?\"<>|\\x00-\\x1f]"));
    stem.remove(badStem);
    while (stem.startsWith(QLatin1Char('.')))
        stem.remove(0, 1);
    if (stem.isEmpty())
        stem = QStringLiteral("subtitle");
    if (!lang.isEmpty())
        stem += QLatin1Char('.') + lang;
    return stem + QStringLiteral(".srt");
}
