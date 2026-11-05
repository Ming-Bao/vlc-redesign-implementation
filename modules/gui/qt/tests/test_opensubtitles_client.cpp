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
#include <QFile>
#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTest>

#include "dialogs/subtitles/opensubtitles_client.hpp"

// A one-route-at-a-time HTTP server on 127.0.0.1: `handler` gets the raw request and returns the whole response.
class FakeServer : public QTcpServer
{
public:
    std::function<QByteArray(const QByteArray&)> handler;
    QList<QByteArray> requests;

    FakeServer() {
        connect(this, &QTcpServer::newConnection, this, [this] {
            while (QTcpSocket* s = nextPendingConnection()) {
                connect(s, &QTcpSocket::readyRead, s, [this, s] {
                    // the test requests are small: the head and body arrive together
                    const QByteArray req = s->readAll();
                    if (req.isEmpty() || !req.contains("\r\n\r\n"))
                        return;
                    requests << req;
                    s->write(handler(req));
                    s->disconnectFromHost();
                });
            }
        });
        listen(QHostAddress::LocalHost);
    }
    QUrl base() const { return QUrl(QStringLiteral("http://127.0.0.1:%1/api/v1").arg(serverPort())); }

    static QByteArray reply(int status, const QByteArray& body, const QByteArray& type = "application/json") {
        return "HTTP/1.1 " + QByteArray::number(status) + " X\r\nContent-Type: " + type + "\r\nContent-Length: "
               + QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body;
    }
};

class TestOpenSubtitlesClient : public QObject
{
    Q_OBJECT
    static QByteArray fixture() {
        QFile f(QFINDTESTDATA("data/opensubtitles_search.json"));
        return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
    }
private slots:
    void initTestCase() { qRegisterMetaType<QVector<SubtitleHit>>(); }

    void parseResults_fromDocsExample() {
        const auto hits = OpenSubtitlesClient::parseResults(fixture());
        QCOMPARE(hits.size(), 2);
        QCOMPARE(hits[0].fileId, 6411421);
        QCOMPARE(hits[0].fileName, QStringLiteral("The.Wand.S01E01.WEB.x264.srt"));
        QCOMPARE(hits[0].language, QStringLiteral("en"));
        QCOMPARE(hits[1].language, QStringLiteral("pt-BR"));
    }
    void parseResults_badInput() {
        QVERIFY(OpenSubtitlesClient::parseResults("not json").isEmpty());
        QVERIFY(OpenSubtitlesClient::parseResults("{\"data\":[{}]}").isEmpty());
        QVERIFY(OpenSubtitlesClient::parseResults("{\"data\":[{\"attributes\":{\"files\":[{\"file_id\":0,\"file_name\":\"a\"}]}}]}").isEmpty());
    }

    void subtitleFileName_isSafe() {
        QCOMPARE(OpenSubtitlesClient::subtitleFileName("The_Wand_S01E01", "en"), QStringLiteral("The_Wand_S01E01.en.srt"));
        QCOMPARE(OpenSubtitlesClient::subtitleFileName("a", "pt-BR"), QStringLiteral("a.pt-br.srt"));
        // nothing a server sends reaches the path
        QCOMPARE(OpenSubtitlesClient::subtitleFileName("a", "../../etc/x"), QStringLiteral("a.etcx.srt"));
        QCOMPARE(OpenSubtitlesClient::subtitleFileName("../../x/y", "en"), QStringLiteral("xy.en.srt"));
        QCOMPARE(OpenSubtitlesClient::subtitleFileName("..", ""), QStringLiteral("subtitle.srt"));
        QVERIFY(!OpenSubtitlesClient::subtitleFileName("a\\b/c", "e/n").contains(QLatin1Char('/')));
        QVERIFY(!OpenSubtitlesClient::subtitleFileName("a\\b/c", "e/n").contains(QLatin1Char('\\')));
    }

    void searchThenDownload() {
        FakeServer server;
        QTemporaryDir dir;
        server.handler = [&](const QByteArray& req) -> QByteArray {
            if (req.startsWith("GET /api/v1/subtitles"))
                return FakeServer::reply(200, fixture());
            if (req.startsWith("POST /api/v1/download"))
                return FakeServer::reply(200, "{\"link\":\"http://127.0.0.1:" + QByteArray::number(server.serverPort())
                                              + "/file/1.srt\",\"file_name\":\"../../evil.srt\",\"remaining\":4}");
            if (req.startsWith("GET /file/1.srt"))
                return FakeServer::reply(200, "1\n00:00:01,000 --> 00:00:02,000\nHi\n", "text/plain");
            return FakeServer::reply(404, "{}");
        };
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy results(&c, &OpenSubtitlesClient::results), failed(&c, &OpenSubtitlesClient::failed);
        c.search("The Wand S01E01", "en");
        QTRY_COMPARE(results.size(), 1);
        QCOMPARE(failed.size(), 0);
        QCOMPARE(results[0][0].value<QVector<SubtitleHit>>().size(), 2);

        const QByteArray searchReq = server.requests[0];
        QVERIFY(searchReq.toLower().contains("api-key: dummy-key"));
        QVERIFY(searchReq.toLower().contains("user-agent: vlc"));

        QSignalSpy done(&c, &OpenSubtitlesClient::downloaded), dfailed(&c, &OpenSubtitlesClient::downloadFailed);
        const QString dest = dir.filePath("a.en.srt");
        c.download(6411421, dest);
        QTRY_COMPARE(done.size(), 1);
        QCOMPARE(dfailed.size(), 0);
        QVERIFY(server.requests[1].contains("{\"file_id\":6411421}"));
        // the file's own request does not carry the key; the server's file_name is not used
        QVERIFY(!server.requests[2].toLower().contains("api-key"));
        QFile f(dest);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(f.readAll().contains("Hi"));
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files).size(), 1);
    }

    // Pins what the real service takes (checked against it on 2026-11-06). It answers a "%20" with a 301 to the "+"
    // form, before looking at the key, and the client follows no redirect: the mock must not accept anything else.
    void search_requestLine_data() {
        QTest::addColumn<QString>("query");
        QTest::addColumn<QString>("language");
        QTest::addColumn<QByteArray>("line");
        QTest::newRow("spaces") << "The Wand S01E01" << "en" << QByteArray("languages=en&query=the+wand+s01e01");
        QTest::newRow("accent") << QString::fromUtf8("Caf\xc3\xa9 Noir") << "en" << QByteArray("languages=en&query=caf%C3%A9+noir");
        QTest::newRow("quote and plus") << "It's 1+1" << "en" << QByteArray("languages=en&query=it%27s+1%2B1");
        QTest::newRow("language case") << "x" << "pt-PT" << QByteArray("languages=pt-pt&query=x");
        QTest::newRow("no language") << "a b" << "" << QByteArray("query=a+b");
        QTest::newRow("reserved") << "a&b=c#d" << "en" << QByteArray("languages=en&query=a%26b%3Dc%23d");
    }
    void search_requestLine() {
        QFETCH(QString, query);
        QFETCH(QString, language);
        QFETCH(QByteArray, line);
        FakeServer server;
        server.handler = [&](const QByteArray&) { return FakeServer::reply(200, "{\"data\":[]}"); };
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy results(&c, &OpenSubtitlesClient::results);
        c.search(query, language);
        QTRY_COMPARE(results.size(), 1);
        const QByteArray first = server.requests[0].left(server.requests[0].indexOf("\r\n"));
        QCOMPARE(first, "GET /api/v1/subtitles?" + line + " HTTP/1.1");
    }

    void httpErrors_data() {
        QTest::addColumn<int>("status");
        QTest::addColumn<QString>("word");
        QTest::newRow("401") << 401 << QStringLiteral("refused");
        QTest::newRow("429") << 429 << QStringLiteral("limit");
        QTest::newRow("500") << 500 << QStringLiteral("500");
    }
    void httpErrors() {
        QFETCH(int, status);
        QFETCH(QString, word);
        FakeServer server;
        server.handler = [&](const QByteArray&) { return FakeServer::reply(status, "{\"message\":\"secret-detail\"}"); };
        QTemporaryDir dir;
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy failed(&c, &OpenSubtitlesClient::failed), dfailed(&c, &OpenSubtitlesClient::downloadFailed);
        c.search("x", "en");
        QTRY_COMPARE(failed.size(), 1);
        QVERIFY2(failed[0][0].toString().contains(word), qPrintable(failed[0][0].toString()));
        // neither the key nor the body is echoed
        QVERIFY(!failed[0][0].toString().contains("dummy-key"));
        QVERIFY(!failed[0][0].toString().contains("secret"));
        c.download(1, dir.filePath("x.srt"));
        QTRY_COMPARE(dfailed.size(), 1);
        QVERIFY(dfailed[0][0].toString().contains(word));
        QVERIFY(QDir(dir.path()).entryList(QDir::Files).isEmpty());
    }

    void malformedBody() {
        FakeServer server;
        server.handler = [&](const QByteArray&) { return FakeServer::reply(200, "<html>not json</html>"); };
        QTemporaryDir dir;
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy failed(&c, &OpenSubtitlesClient::failed), dfailed(&c, &OpenSubtitlesClient::downloadFailed),
                   results(&c, &OpenSubtitlesClient::results);
        c.search("x", "en");
        QTRY_COMPARE(failed.size(), 1);
        QCOMPARE(results.size(), 0);
        c.download(1, dir.filePath("x.srt"));
        QTRY_COMPARE(dfailed.size(), 1);
        QVERIFY(QDir(dir.path()).entryList(QDir::Files).isEmpty());
    }

    void isSafeFileLink_table() {
        const char* ok[] = {"https://dl.opensubtitles.org/en/download/sub/1", "https://example.com:8443/a.srt",
                            "https://8.8.8.8/a", "https://[2606:4700::1111]/a"};
        const char* bad[] = {"file:///etc/passwd", "ftp://example.com/a.srt", "http://example.com/a.srt", "", "https:///a",
                             "https://localhost/a", "https://x.localhost/a", "https://127.0.0.1/a", "https://127.1.2.3/a",
                             "https://10.0.0.5/a", "https://172.16.0.1/a", "https://172.31.255.255/a", "https://192.168.1.1/a",
                             "https://169.254.169.254/a", "https://0.0.0.0/a", "https://100.64.0.1/a", "https://[::1]/a",
                             "https://[::]/a", "https://[fd00::1]/a", "https://[fe80::1]/a", "https://[::ffff:127.0.0.1]/a",
                             "https://2130706433/a", "https://0x7f.1/a"};
        for (const char* u : ok)
            QVERIFY2(OpenSubtitlesClient::isSafeFileLink(QUrl(QString::fromLatin1(u))), u);
        for (const char* u : bad)
            QVERIFY2(!OpenSubtitlesClient::isSafeFileLink(QUrl(QString::fromLatin1(u))), u);
        QVERIFY(OpenSubtitlesClient::isSafeFileLink(QUrl("https://172.32.0.1/a"))); // outside 172.16/12
    }

    void oversizedBody_data() {
        QTest::addColumn<bool>("withLength");
        QTest::newRow("with Content-Length") << true;
        QTest::newRow("without Content-Length") << false;
    }
    void oversizedBody() {
        QFETCH(bool, withLength);
        const QByteArray big(6 * 1024 * 1024, 'x');
        FakeServer server;
        QTemporaryDir dir;
        auto answer = [&](const QByteArray& body) {
            return withLength ? FakeServer::reply(200, body)
                              : "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n" + body;
        };
        server.handler = [&](const QByteArray& req) -> QByteArray {
            if (req.startsWith("GET /file"))
                return answer(big);
            if (req.startsWith("POST"))
                return FakeServer::reply(200, "{\"link\":\"http://127.0.0.1:" + QByteArray::number(server.serverPort()) + "/file\"}");
            return answer("{\"data\":[],\"pad\":\"" + big + "\"}");
        };
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy failed(&c, &OpenSubtitlesClient::failed), results(&c, &OpenSubtitlesClient::results),
                   dfailed(&c, &OpenSubtitlesClient::downloadFailed), done(&c, &OpenSubtitlesClient::downloaded);
        c.search("x", "en");
        QTRY_COMPARE_WITH_TIMEOUT(failed.size(), 1, 10000);
        QCOMPARE(results.size(), 0);
        QVERIFY2(failed[0][0].toString().contains("more data"), qPrintable(failed[0][0].toString()));
        c.download(1, dir.filePath("x.srt"));
        QTRY_COMPARE_WITH_TIMEOUT(dfailed.size(), 1, 10000);
        QCOMPARE(done.size(), 0);
        QVERIFY(QDir(dir.path()).entryList(QDir::Files).isEmpty());
    }

    void apiRedirect_isNotFollowed() {
        FakeServer server;
        server.handler = [&](const QByteArray&) -> QByteArray {
            return "HTTP/1.1 302 Found\r\nLocation: /api/v1/elsewhere\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        };
        QTemporaryDir dir;
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy failed(&c, &OpenSubtitlesClient::failed), dfailed(&c, &OpenSubtitlesClient::downloadFailed);
        c.search("x", "en");
        QTRY_COMPARE(failed.size(), 1);
        c.download(1, dir.filePath("x.srt"));
        QTRY_COMPARE(dfailed.size(), 1);
        // one request each: the key was never sent again
        QCOMPARE(server.requests.size(), 2);
        QVERIFY(QDir(dir.path()).entryList(QDir::Files).isEmpty());
    }

    void fileLink_notAllowed() {
        FakeServer server;
        server.handler = [&](const QByteArray& req) -> QByteArray {
            if (req.startsWith("POST"))
                return FakeServer::reply(200, "{\"link\":\"ftp://127.0.0.1/x.srt\"}");
            return FakeServer::reply(404, "{}");
        };
        QTemporaryDir dir;
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy dfailed(&c, &OpenSubtitlesClient::downloadFailed);
        c.download(1, dir.filePath("x.srt"));
        QTRY_COMPARE(dfailed.size(), 1);
        QCOMPARE(server.requests.size(), 1); // the link was never fetched
    }

    void abort_leavesNoSignalBehind() {
        FakeServer server;
        server.handler = [&](const QByteArray&) { return FakeServer::reply(200, fixture()); };
        OpenSubtitlesClient c("dummy-key", server.base());
        QSignalSpy results(&c, &OpenSubtitlesClient::results), failed(&c, &OpenSubtitlesClient::failed);
        c.search("x", "en");
        c.abort();
        QTest::qWait(300);
        QCOMPARE(results.size() + failed.size(), 0);
    }

    void unreachableServer() {
        quint16 port;
        { FakeServer s; port = s.serverPort(); } // closed again
        OpenSubtitlesClient c("dummy-key", QUrl(QStringLiteral("http://127.0.0.1:%1/api/v1").arg(port)));
        QSignalSpy failed(&c, &OpenSubtitlesClient::failed);
        c.search("x", "en");
        QTRY_COMPARE(failed.size(), 1);
    }
};

QTEST_GUILESS_MAIN(TestOpenSubtitlesClient)
#include "test_opensubtitles_client.moc"
