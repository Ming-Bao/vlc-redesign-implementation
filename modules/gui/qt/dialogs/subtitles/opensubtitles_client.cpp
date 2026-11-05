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
#include <QHostAddress>
#include <QRegularExpression>
#include <QSaveFile>

namespace {
constexpr int TimeoutMs = 20000;
constexpr qint64 MaxSubtitleBytes = 5 * 1024 * 1024;
}

OpenSubtitlesClient::OpenSubtitlesClient(const QString& apiKey, const QUrl& baseUrl, QObject* parent)
    : QObject(parent), m_key(apiKey.trimmed()), m_base(baseUrl),
      m_strict(baseUrl.host() == defaultBaseUrl().host()), m_nam(new QNetworkAccessManager(this))
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
    // redirects are never followed by Qt: an API call fails on one (the key stays put), a file fetch checks each hop
    r.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    r.setTransferTimeout(TimeoutMs);
    return r;
}

// never the body or the URL: only what the user can act on
QString OpenSubtitlesClient::errorFor(QNetworkReply* reply, const QByteArray&)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (reply->property("tooBig").toBool())
        return tr("OpenSubtitles sent more data than VLC accepts");
    if (status == 401 || status == 403)
        return tr("OpenSubtitles refused the API key");
    if (status == 429)
        return tr("OpenSubtitles limit reached, try again later");
    if (status >= 300)
        return tr("OpenSubtitles answered with error %1").arg(status);
    if (reply->error() == QNetworkReply::OperationCanceledError || reply->error() == QNetworkReply::TimeoutError)
        return tr("OpenSubtitles did not answer in time");
    return tr("Could not reach OpenSubtitles");
}

// Drains the reply as it arrives into the returned buffer, so Qt never holds more than the cap, and aborts once
// the body passes it or a Content-Length announces that it will.
std::shared_ptr<QByteArray> OpenSubtitlesClient::capSize(QNetworkReply* reply)
{
    auto body = std::make_shared<QByteArray>();
    auto tooBig = [reply] {
        reply->setProperty("tooBig", true);
        reply->abort();
    };
    connect(reply, &QNetworkReply::readyRead, reply, [reply, body, tooBig] {
        body->append(reply->readAll());
        if (body->size() > MaxSubtitleBytes)
            tooBig();
    });
    connect(reply, &QNetworkReply::downloadProgress, reply, [tooBig](qint64, qint64 total) {
        if (total > MaxSubtitleBytes)
            tooBig();
    });
    return body;
}

// a reply that finished with a 2xx
static bool succeeded(QNetworkReply* reply)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    return reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
}

bool OpenSubtitlesClient::isSafeFileLink(const QUrl& url)
{
    if (!url.isValid() || url.scheme() != QLatin1String("https"))
        return false;
    const QString host = url.host().toLower();
    if (host.isEmpty() || host == QLatin1String("localhost") || host.endsWith(QLatin1String(".localhost")))
        return false;
    // a numeric last label is an address in some spelling ("2130706433", "0x7f.1"); no host name ends that way
    const QString last = host.section(QLatin1Char('.'), -1);
    static const QRegularExpression numeric(QStringLiteral("^(0x[0-9a-f]*|[0-9]+)$"));
    QHostAddress addr;
    if (!addr.setAddress(host))
        return !numeric.match(last).hasMatch();
    bool v4 = false;
    const quint32 a = addr.toIPv4Address(&v4); // also reads an IPv4-mapped IPv6 address
    if (v4) {
        const quint8 b0 = a >> 24, b1 = (a >> 16) & 0xff;
        return !(b0 == 0 || b0 == 10 || b0 == 127 || b0 >= 224 || (b0 == 169 && b1 == 254)
                 || (b0 == 172 && (b1 & 0xf0) == 16) || (b0 == 192 && b1 == 168) || (b0 == 100 && (b1 & 0xc0) == 64));
    }
    const Q_IPV6ADDR b = addr.toIPv6Address();
    return !(addr.isNull() || addr == QHostAddress(QHostAddress::LocalHostIPv6) || b[0] == 0xff
             || (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80)
             || addr == QHostAddress(QHostAddress::AnyIPv6));
}

bool OpenSubtitlesClient::linkAllowed(const QUrl& url) const
{
    if (m_strict)
        return isSafeFileLink(url);
    return url.isValid() && (url.scheme() == QLatin1String("https") || url.scheme() == QLatin1String("http"));
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
    // the API's own form: lower case, alphabetical order, "+" for a space. It answers a "%20" with a redirect before it
    // looks at the key, and request() follows none. QUrlQuery can't write this: it leaves "+" and "'" unencoded.
    const QByteArray text = QUrl::toPercentEncoding(query.toLower()).replace("%20", "+");
    QString params = QStringLiteral("query=") + QString::fromLatin1(text);
    if (!language.isEmpty())
        params.prepend(QStringLiteral("languages=%1&").arg(QString::fromLatin1(QUrl::toPercentEncoding(language.toLower()))));
    QUrl url(m_base.toString() + QStringLiteral("/subtitles"));
    url.setQuery(params);

    QNetworkReply* reply = m_search = m_nam->get(request(url, true));
    const auto buffer = capSize(reply);
    connect(reply, &QNetworkReply::finished, this, [this, reply, buffer] {
        m_search = nullptr;
        reply->deleteLater();
        const QByteArray body = *buffer + reply->readAll();
        if (!succeeded(reply))
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
    const auto buffer = capSize(reply);
    connect(reply, &QNetworkReply::finished, this, [this, reply, buffer, destPath] {
        reply->deleteLater();
        const QByteArray body = *buffer + reply->readAll();
        if (!succeeded(reply)) {
            m_download = nullptr;
            return emit downloadFailed(errorFor(reply, body));
        }
        const QUrl link(QJsonDocument::fromJson(body).object().value(QStringLiteral("link")).toString());
        m_download = nullptr;
        fetchFile(link, 0, destPath);
    });
}

// the file's own host never sees the key; every hop, the first included, must pass linkAllowed
void OpenSubtitlesClient::fetchFile(const QUrl& url, int redirects, const QString& destPath)
{
    if (!linkAllowed(url))
        return emit downloadFailed(tr("OpenSubtitles sent an answer VLC does not understand"));
    QNetworkReply* file = m_download = m_nam->get(request(url, false));
    const auto buffer = capSize(file);
    connect(file, &QNetworkReply::finished, this, [this, file, buffer, url, redirects, destPath] {
        m_download = nullptr;
        file->deleteLater();
        const int status = file->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (file->error() == QNetworkReply::NoError && status >= 300 && status < 400) {
            const QUrl next = url.resolved(file->header(QNetworkRequest::LocationHeader).toUrl());
            if (redirects >= 3 || !next.isValid())
                return emit downloadFailed(tr("Could not reach OpenSubtitles"));
            return fetchFile(next, redirects + 1, destPath);
        }
        const QByteArray data = *buffer + file->readAll();
        if (!succeeded(file))
            return emit downloadFailed(errorFor(file, data));
        if (data.isEmpty() || data.size() > MaxSubtitleBytes)
            return emit downloadFailed(tr("OpenSubtitles sent an answer VLC does not understand"));
        QSaveFile out(destPath);
        if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.commit())
            return emit downloadFailed(tr("Could not save the subtitle file"));
        emit downloaded(destPath);
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
