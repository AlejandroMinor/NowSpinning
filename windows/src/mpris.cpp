#include "mpris.h"

#include <QDateTime>
#include <QRegularExpression>
#include <QtDebug>

#include <algorithm>

MprisPlayer::MprisPlayer(MediaBackend* backend, const QString& dbusName, const MediaSnapshot& state, QObject* parent)
    : QObject(parent)
    , m_backend(backend)
    , m_dbusName(dbusName)
    , m_state(state) {}

void MprisPlayer::update(const MediaSnapshot& s) {
    const MediaSnapshot old = m_state;
    m_state = s;
    if ((old.title != s.title || old.artist != s.artist) && !s.title.isEmpty())
        logTrack();

    if (old.playing != s.playing)
        Q_EMIT isPlayingChanged();
    if (old.title != s.title || old.artist != s.artist || old.album != s.album || old.artUrl != s.artUrl
        || old.url != s.url || old.length != s.length)
        Q_EMIT trackChanged();
    if (old.canPrevious != s.canPrevious || old.canNext != s.canNext || old.canToggle != s.canToggle
        || old.canSeek != s.canSeek)
        Q_EMIT controlsChanged();
    if (old.position != s.position || old.positionAt != s.positionAt || old.playing != s.playing
        || old.rate != s.rate)
        Q_EMIT positionChanged();
    if (old.volumeKnown != s.volumeKnown || old.volume != s.volume)
        Q_EMIT volumeChanged();
}

// In the log, to tell which players the widget sees and what they play.
void MprisPlayer::logTrack() const {
    qInfo().noquote() << m_dbusName + QStringLiteral(":") << m_state.title
                      << (m_state.artist.isEmpty() ? QString() : QStringLiteral("by ") + m_state.artist);
}

QVariantMap MprisPlayer::metadata() const {
    QVariantMap map;
    map.insert(QStringLiteral("xesam:title"), m_state.title);
    map.insert(QStringLiteral("xesam:artist"), QStringList{m_state.artist});
    map.insert(QStringLiteral("xesam:album"), m_state.album);
    if (!m_state.artUrl.isEmpty())
        map.insert(QStringLiteral("mpris:artUrl"), m_state.artUrl);
    if (!m_state.url.isEmpty())
        map.insert(QStringLiteral("xesam:url"), m_state.url);
    if (m_state.length > 0)
        map.insert(QStringLiteral("mpris:length"), qint64(m_state.length * 1e6));
    return map;
}

qreal MprisPlayer::position() const {
    double position = m_state.position;
    if (m_state.playing && m_state.positionAt > 0) {
        const qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - m_state.positionAt;
        if (elapsed > 0)
            position += elapsed / 1000.0 * m_state.rate;
    }
    if (m_state.length > 0)
        position = std::min(position, m_state.length);
    return std::max(0.0, position);
}

void MprisPlayer::setPosition(qreal position) {
    if (!m_state.canSeek)
        return;
    m_backend->seek(m_state.id, position);
    m_state.position = position;
    m_state.positionAt = QDateTime::currentMSecsSinceEpoch();
    Q_EMIT positionChanged();
}

void MprisPlayer::setVolume(qreal volume) {
    if (!m_state.volumeKnown)
        return;
    volume = std::clamp(volume, 0.0, 1.0);
    m_backend->setVolume(m_state.id, volume);
    if (volume != m_state.volume) {
        m_state.volume = volume;
        Q_EMIT volumeChanged();
    }
}

void MprisPlayer::togglePlaying() {
    m_backend->togglePlaying(m_state.id);
}

void MprisPlayer::play() {
    if (!m_state.playing)
        m_backend->togglePlaying(m_state.id);
}

void MprisPlayer::pause() {
    if (m_state.playing)
        m_backend->togglePlaying(m_state.id);
}

void MprisPlayer::next() {
    m_backend->next(m_state.id);
}

void MprisPlayer::previous() {
    m_backend->previous(m_state.id);
}

void MprisPlayers::setValues(const QVariantList& values) {
    if (values == m_values)
        return;
    m_values = values;
    Q_EMIT valuesChanged();
}

Mpris::Mpris(QObject* parent)
    : QObject(parent)
    , m_backend(MediaBackend::create(this))
    , m_players(new MprisPlayers(this)) {
    connect(m_backend, &MediaBackend::updated, this, &Mpris::update);
}

QString Mpris::busName(const QString& app) {
    // Spotify.exe, Chrome, MSEdge, or for a Store app,
    // SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify: the part after the "!".
    QString name = app.section(QLatin1Char('!'), -1);
    name = name.section(QLatin1Char('\\'), -1).section(QLatin1Char('/'), -1);
    if (name.endsWith(QLatin1String(".exe"), Qt::CaseInsensitive))
        name.chop(4);
    name = name.toLower();
    static const QRegularExpression invalid(QStringLiteral("[^a-z0-9._-]+"));
    name.replace(invalid, QStringLiteral("_"));
    while (name.startsWith(QLatin1Char('.')))
        name.remove(0, 1);
    if (name.isEmpty())
        name = QStringLiteral("player");
    return QStringLiteral("org.mpris.MediaPlayer2.") + name;
}

void Mpris::update(const QList<MediaSnapshot>& players) {
    QVariantList values;
    QHash<QString, MprisPlayer*> kept;

    for (const MediaSnapshot& state : players) {
        MprisPlayer* player = m_byId.take(state.id);
        if (player) {
            player->update(state);
        } else {
            // Two sessions of the same app: the second is told apart the
            // way MPRIS does, with an instance number.
            const QString base = busName(state.app);
            QString name = base;
            auto taken = [&](const QString& n) {
                for (MprisPlayer* p : std::as_const(kept))
                    if (p->dbusName() == n)
                        return true;
                for (MprisPlayer* p : std::as_const(m_byId))
                    if (p->dbusName() == n)
                        return true;
                return false;
            };
            for (int i = 2; taken(name); i++)
                name = base + QStringLiteral(".instance") + QString::number(i);
            player = new MprisPlayer(m_backend, name, state, this);
            qInfo().noquote() << "Player" << name << "from" << state.app;
            if (!state.title.isEmpty())
                player->logTrack();
        }
        kept.insert(state.id, player);
        values.append(QVariant::fromValue(static_cast<QObject*>(player)));
    }

    const QList<MprisPlayer*> gone = m_byId.values();
    m_byId = kept;
    m_players->setValues(values);
    for (MprisPlayer* player : gone)
        player->deleteLater();
}
