// Quickshell.Services.Mpris, fed by the system's own players instead of
// D-Bus: `Mpris.players.values`, each with the same properties and calls
// MprisSource.qml uses. Each player gets an MPRIS style bus name made from
// its app, so `preferredPlayer` keeps working: Spotify is
// "org.mpris.MediaPlayer2.spotify" here too.
#pragma once

#include "media.h"

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class MprisPlayer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString dbusName READ dbusName CONSTANT)
    Q_PROPERTY(QString identity READ identity CONSTANT)
    Q_PROPERTY(QString uniqueId READ uniqueId CONSTANT)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackAlbum READ trackAlbum NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtUrl READ trackArtUrl NOTIFY trackChanged)
    Q_PROPERTY(QVariantMap metadata READ metadata NOTIFY trackChanged)
    Q_PROPERTY(bool canControl READ canControl CONSTANT)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY controlsChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY controlsChanged)
    Q_PROPERTY(bool canTogglePlaying READ canTogglePlaying NOTIFY controlsChanged)
    Q_PROPERTY(bool canPlay READ canTogglePlaying NOTIFY controlsChanged)
    Q_PROPERTY(bool canPause READ canTogglePlaying NOTIFY controlsChanged)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY controlsChanged)
    Q_PROPERTY(bool lengthSupported READ lengthSupported NOTIFY trackChanged)
    Q_PROPERTY(qreal length READ length NOTIFY trackChanged)
    Q_PROPERTY(bool positionSupported READ positionSupported NOTIFY trackChanged)
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool volumeSupported READ volumeSupported NOTIFY volumeChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    MprisPlayer(MediaBackend* backend, const QString& dbusName, const MediaSnapshot& state, QObject* parent);

    void update(const MediaSnapshot& state);
    void logTrack() const;

    QString dbusName() const { return m_dbusName; }
    QString identity() const { return m_state.app; }
    QString uniqueId() const { return m_state.id; }
    bool isPlaying() const { return m_state.playing; }
    QString trackTitle() const { return m_state.title; }
    QString trackArtist() const { return m_state.artist; }
    QString trackAlbum() const { return m_state.album; }
    QString trackArtUrl() const { return m_state.artUrl; }
    QVariantMap metadata() const;
    bool canControl() const { return true; }
    bool canGoPrevious() const { return m_state.canPrevious; }
    bool canGoNext() const { return m_state.canNext; }
    bool canTogglePlaying() const { return m_state.canToggle; }
    bool canSeek() const { return m_state.canSeek; }
    bool lengthSupported() const { return m_state.length > 0; }
    qreal length() const { return m_state.length; }
    bool positionSupported() const { return m_state.length > 0; }
    // Worked out on each read: where it was last reported, plus the time
    // since, while it plays.
    qreal position() const;
    void setPosition(qreal position);
    bool volumeSupported() const { return m_state.volumeKnown; }
    qreal volume() const { return m_state.volume; }
    void setVolume(qreal volume);

    Q_INVOKABLE void togglePlaying();
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();

Q_SIGNALS:
    void isPlayingChanged();
    void trackChanged();
    void controlsChanged();
    void positionChanged();
    void volumeChanged();

private:
    MediaBackend* m_backend;
    QString m_dbusName;
    MediaSnapshot m_state;
};

// `Mpris.players`: its `values` are the players, a plain array.
class MprisPlayers : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList values READ values NOTIFY valuesChanged)

public:
    using QObject::QObject;
    QVariantList values() const { return m_values; }
    void setValues(const QVariantList& values);

Q_SIGNALS:
    void valuesChanged();

private:
    QVariantList m_values;
};

class Mpris : public QObject {
    Q_OBJECT
    Q_PROPERTY(MprisPlayers* players READ players CONSTANT)

public:
    explicit Mpris(QObject* parent = nullptr);
    MprisPlayers* players() const { return m_players; }

    // The bus name a player gets: its app, the way an MPRIS name reads.
    static QString busName(const QString& app);

private:
    void update(const QList<MediaSnapshot>& players);

    MediaBackend* m_backend;
    MprisPlayers* m_players;
    QHash<QString, MprisPlayer*> m_byId;
};
