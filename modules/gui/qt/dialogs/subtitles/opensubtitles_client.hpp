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
#ifndef VLC_QT_OPENSUBTITLES_CLIENT_HPP
#define VLC_QT_OPENSUBTITLES_CLIENT_HPP

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVector>

#include <memory>

class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

struct SubtitleHit
{
    int fileId = 0;
    QString fileName;
    QString language;
};

// The OpenSubtitles REST API (https://api.opensubtitles.com/api/v1). The key goes to the base URL's host
// only: the file link a download returns is fetched without it. The key is never logged or put in an error.
class OpenSubtitlesClient : public QObject
{
    Q_OBJECT
public:
    // the only host the application uses; the constructor's URL exists for the tests
    static QUrl defaultBaseUrl() { return QUrl(QStringLiteral("https://api.opensubtitles.com/api/v1")); }

    explicit OpenSubtitlesClient(const QString& apiKey, const QUrl& baseUrl = defaultBaseUrl(), QObject* parent = nullptr);

    // language: an OpenSubtitles code ("en", "pt-br"), empty for any
    void search(const QString& query, const QString& language);
    // fetches the file to destPath, written whole or not at all
    void download(int fileId, const QString& destPath);
    // drops what is in flight; no signal follows
    void abort();

    static QVector<SubtitleHit> parseResults(const QByteArray& json);
    // "<stem>.<language>.srt" for a media: the name is built from the local stem and a language code kept to
    // [a-z0-9-], so nothing a server sends can name a path
    // a link the file may be fetched from when the client talks to the real service: https, and a host that is
    // not "localhost" or a loopback, private or link-local address (checked on the literal, no DNS lookup)
    static bool isSafeFileLink(const QUrl& url);
    static QString subtitleFileName(const QString& mediaStem, const QString& language);

signals:
    void results(QVector<SubtitleHit> hits);
    void failed(QString message);
    void downloaded(QString path);
    void downloadFailed(QString message);

private:
    QNetworkRequest request(const QUrl& url, bool withKey) const;
    // aborts a reply that sends more than MaxSubtitleBytes, whether or not it announced a length
    static std::shared_ptr<QByteArray> capSize(QNetworkReply* reply);
    bool linkAllowed(const QUrl& url) const;
    void fetchFile(const QUrl& url, int redirects, const QString& destPath);
    static QString errorFor(QNetworkReply* reply, const QByteArray& body);

    QString m_key;
    QUrl m_base;
    bool m_strict; // the real service: file links must pass isSafeFileLink
    QNetworkAccessManager* m_nam;
    QNetworkReply* m_search = nullptr;
    QNetworkReply* m_download = nullptr;
};

Q_DECLARE_METATYPE(SubtitleHit)

#endif
