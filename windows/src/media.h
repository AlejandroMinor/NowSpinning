// Where the players come from. On Windows, its media controls (the same
// sessions the volume flyout shows: Spotify, browsers, most players); on
// other systems nothing, unless NOWSPINNING_DEMO is set, which plays a
// made-up track for trying the widget without a player (with the picture
// it names as the cover, if it names one).
#pragma once

#include <QByteArray>
#include <QList>
#include <QMetaType>
#include <QObject>
#include <QString>

// One player as it is right now.
struct MediaSnapshot {
    QString id;      // stable while the session lasts
    QString app;     // the app it belongs to (its AppUserModelID on Windows)
    QString title;
    QString artist;
    QString album;
    QString artUrl;  // a file:// URL, or empty
    QString url;     // the page or file playing, if known
    bool playing = false;
    bool canPrevious = false;
    bool canNext = false;
    bool canToggle = false;
    bool canSeek = false;
    double length = 0;       // seconds; 0 when unknown
    double position = 0;     // seconds, at positionAt
    qint64 positionAt = 0;   // ms since the epoch
    double rate = 1;
    bool volumeKnown = false;
    double volume = 0;       // 0..1
};
Q_DECLARE_METATYPE(MediaSnapshot)

class MediaBackend : public QObject {
    Q_OBJECT

public:
    using QObject::QObject;

    // The backend for this system. Never null.
    static MediaBackend* create(QObject* parent);

    virtual void togglePlaying(const QString& id) = 0;
    virtual void next(const QString& id) = 0;
    virtual void previous(const QString& id) = 0;
    virtual void seek(const QString& id, double seconds) = 0;
    virtual void setVolume(const QString& id, double volume) = 0;

Q_SIGNALS:
    // Every player there is, each time anything about any of them changes.
    void updated(const QList<MediaSnapshot>& players);
};

namespace ArtCache {
// Keeps a cover's bytes in a file under the temporary folder and returns
// its file:// URL, the same file for the same cover. Only the last few are
// kept. Thread safe.
QString store(const QByteArray& bytes, const QString& contentType = QString());
} // namespace ArtCache
