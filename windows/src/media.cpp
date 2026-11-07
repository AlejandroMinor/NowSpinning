#include "media.h"

#include <QBuffer>
#include <QColor>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QLinearGradient>
#include <QMutex>
#include <QPainter>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace ArtCache {

namespace {
QMutex mutex;
constexpr int keep = 12;

QString extensionFor(const QByteArray& bytes, const QString& contentType) {
    if (contentType.contains(QLatin1String("png"), Qt::CaseInsensitive) || bytes.startsWith("\x89PNG"))
        return QStringLiteral("png");
    if (contentType.contains(QLatin1String("bmp"), Qt::CaseInsensitive) || bytes.startsWith("BM"))
        return QStringLiteral("bmp");
    if (bytes.startsWith("RIFF") && bytes.mid(8, 4) == "WEBP")
        return QStringLiteral("webp");
    return QStringLiteral("jpg");
}
} // namespace

QString store(const QByteArray& bytes, const QString& contentType) {
    if (bytes.isEmpty())
        return QString();

    QMutexLocker lock(&mutex);
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
        + QStringLiteral("/nowspinning-art");
    QDir().mkpath(dir);

    const QString name = QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha1).toHex().left(16))
        + QLatin1Char('.') + extensionFor(bytes, contentType);
    const QString path = dir + QLatin1Char('/') + name;

    QFile file(path);
    if (file.exists()) {
        // Kept among the newest, not pruned as an old one.
        file.open(QIODevice::ReadWrite);
        file.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
        file.close();
    } else {
        if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size())
            return QString();
        file.close();

        // The widget shows this one and maybe the last few (the Polaroid's
        // stack): older ones go.
        const QFileInfoList all = QDir(dir).entryInfoList(QDir::Files, QDir::Time);
        for (qsizetype i = keep; i < all.size(); i++)
            QFile::remove(all[i].absoluteFilePath());
    }
    return QUrl::fromLocalFile(path).toString();
}

} // namespace ArtCache

// A made-up player, for trying the widget with no player around: on a
// system without one of its own, and with NOWSPINNING_DEMO set.
class DemoBackend : public MediaBackend {
public:
    explicit DemoBackend(QObject* parent)
        : MediaBackend(parent) {
        m_state.id = QStringLiteral("demo");
        m_state.app = QStringLiteral("NowSpinning demo");
        m_state.playing = true;
        m_state.canPrevious = m_state.canNext = m_state.canToggle = m_state.canSeek = true;
        m_state.volumeKnown = true;
        m_state.volume = 0.6;
        m_state.length = 214;
        m_state.positionAt = QDateTime::currentMSecsSinceEpoch();
        setTrack(0);
        QTimer::singleShot(0, this, &DemoBackend::publish);
    }

    void togglePlaying(const QString&) override {
        m_state.position = currentPosition();
        m_state.positionAt = QDateTime::currentMSecsSinceEpoch();
        m_state.playing = !m_state.playing;
        publish();
    }
    void next(const QString&) override { setTrack(m_track + 1); publish(); }
    void previous(const QString&) override { setTrack(m_track - 1); publish(); }
    void seek(const QString&, double seconds) override {
        m_state.position = seconds;
        m_state.positionAt = QDateTime::currentMSecsSinceEpoch();
        publish();
    }
    void setVolume(const QString&, double volume) override {
        m_state.volume = volume;
        publish();
    }

private:
    double currentPosition() const {
        double p = m_state.position;
        if (m_state.playing)
            p += (QDateTime::currentMSecsSinceEpoch() - m_state.positionAt) / 1000.0;
        return p;
    }

    void setTrack(int track) {
        static const char* titles[] = {"Blue in Green", "Night Drive", "Paper Moons"};
        static const char* artists[] = {"The Demo Quartet", "Sample Rate", "Placeholder"};
        static const QColor colors[][2] = {
            {QColor(0x1d3557), QColor(0xe9c46a)},
            {QColor(0x2a0845), QColor(0xff6a88)},
            {QColor(0x0b6e4f), QColor(0xf2e8cf)},
        };
        m_track = ((track % 3) + 3) % 3;
        m_state.title = QString::fromLatin1(titles[m_track]);
        m_state.artist = QString::fromLatin1(artists[m_track]);
        m_state.album = QStringLiteral("NowSpinning");
        m_state.position = 0;
        m_state.positionAt = QDateTime::currentMSecsSinceEpoch();

        QImage image(300, 300, QImage::Format_RGB32);
        QPainter painter(&image);
        QLinearGradient gradient(0, 0, 300, 300);
        gradient.setColorAt(0, colors[m_track][0]);
        gradient.setColorAt(1, colors[m_track][0].darker(160));
        painter.fillRect(image.rect(), gradient);
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setPen(Qt::NoPen);
        painter.setBrush(colors[m_track][1]);
        painter.drawEllipse(QPointF(150 + (m_track - 1) * 40, 130), 78, 78);
        painter.setBrush(colors[m_track][0].lighter(130));
        painter.drawRect(0, 210, 300, 90);
        painter.end();

        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");
        m_state.artUrl = ArtCache::store(bytes, QStringLiteral("image/png"));
    }

    void publish() { Q_EMIT updated({m_state}); }

    MediaSnapshot m_state;
    int m_track = 0;
};

MediaBackend* createDemoBackend(QObject* parent) {
    return new DemoBackend(parent);
}
