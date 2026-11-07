// The players on Windows: its media controls (Global System Media Transport
// Controls), the sessions apps open to show in the volume flyout and on the
// lock screen. Spotify, the browsers and most players have one. A session
// gives the track, its cover, the playback state and the timeline, and
// takes play/pause, next, previous and seek.
//
// Volume isn't part of a session: it's the app's own volume in the Windows
// mixer, found by matching the app to the processes playing audio.
//
// All of it runs on a thread of its own: the calls into Windows block, and
// its events come in on threads of Windows' choosing. What the widget sees
// is a snapshot of every session, sent over each time something changes,
// and checked again every second in case an app forgets to say.
#include "media.h"

#include <QDateTime>
#include <QFileInfo>
#include <QThread>
#include <QTimer>
#include <QtDebug>

#include <windows.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>

#include <atomic>
#include <chrono>
#include <map>
#include <memory>
#include <set>
#include <vector>

MediaBackend* createDemoBackend(QObject* parent);

namespace {

namespace wf = winrt::Windows::Foundation;
namespace wmc = winrt::Windows::Media::Control;
namespace wss = winrt::Windows::Storage::Streams;

using Session = wmc::GlobalSystemMediaTransportControlsSession;
using Manager = wmc::GlobalSystemMediaTransportControlsSessionManager;
using Status = wmc::GlobalSystemMediaTransportControlsSessionPlaybackStatus;

QString toQString(const winrt::hstring& s) {
    return QString::fromWCharArray(s.c_str(), int(s.size()));
}

double toSeconds(wf::TimeSpan span) {
    return std::chrono::duration<double>(span).count();
}

// A DateTime counts 100 ns ticks since 1601; zero means never set.
qint64 toMsSinceEpoch(wf::DateTime time) {
    const int64_t ticks = time.time_since_epoch().count();
    if (ticks <= 0)
        return 0;
    constexpr int64_t unixEpoch = 116444736000000000; // 1970-01-01 in those ticks
    return (ticks - unixEpoch) / 10000;
}

QString processName(DWORD pid) {
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process)
        return QString();
    wchar_t path[MAX_PATH];
    DWORD size = MAX_PATH;
    QString name;
    if (QueryFullProcessImageNameW(process, 0, path, &size))
        name = QFileInfo(QString::fromWCharArray(path, int(size))).completeBaseName().toLower();
    CloseHandle(process);
    return name;
}

// The apps playing sound through the default output, and their volume in
// the mixer.
class AppVolumes {
public:
    void refresh() {
        m_entries.clear();
        try {
            auto devices = winrt::create_instance<IMMDeviceEnumerator>(__uuidof(MMDeviceEnumerator));
            winrt::com_ptr<IMMDevice> device;
            winrt::check_hresult(devices->GetDefaultAudioEndpoint(eRender, eMultimedia, device.put()));
            winrt::com_ptr<IAudioSessionManager2> manager;
            winrt::check_hresult(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, nullptr,
                                                  manager.put_void()));
            winrt::com_ptr<IAudioSessionEnumerator> sessions;
            winrt::check_hresult(manager->GetSessionEnumerator(sessions.put()));
            int count = 0;
            winrt::check_hresult(sessions->GetCount(&count));
            for (int i = 0; i < count; i++) {
                winrt::com_ptr<IAudioSessionControl> control;
                if (FAILED(sessions->GetSession(i, control.put())))
                    continue;
                auto control2 = control.try_as<IAudioSessionControl2>();
                auto volume = control.try_as<ISimpleAudioVolume>();
                DWORD pid = 0;
                if (!control2 || !volume || FAILED(control2->GetProcessId(&pid)) || pid == 0)
                    continue;
                const QString exe = processName(pid);
                if (!exe.isEmpty())
                    m_entries.push_back({exe, volume});
            }
        } catch (const winrt::hresult_error&) {
            // No output device, or no mixer: no volume, nothing else lost.
            m_entries.clear();
        }
    }

    // An app's sessions: Spotify.exe for spotify.exe, Chrome for
    // chrome.exe, a Store app's ID for its program.
    std::vector<ISimpleAudioVolume*> find(const QString& app) const {
        const QString key = app.toLower();
        std::vector<ISimpleAudioVolume*> found;
        for (const auto& entry : m_entries) {
            if (entry.exe.size() >= 3 && key.contains(entry.exe))
                found.push_back(entry.volume.get());
        }
        return found;
    }

private:
    struct Entry {
        QString exe;
        winrt::com_ptr<ISimpleAudioVolume> volume;
    };
    std::vector<Entry> m_entries;
};

} // namespace

namespace winmedia {

class Worker : public QObject {
    Q_OBJECT

public:
    Worker()
        : m_alive(std::make_shared<std::atomic<bool>>(true)) {}

    void start() {
        try {
            winrt::init_apartment(winrt::apartment_type::multi_threaded);
        } catch (const winrt::hresult_error&) {
            // Initialized already, whichever way: it still works.
        }

        m_poll = new QTimer(this);
        m_poll->setInterval(1000);
        connect(m_poll, &QTimer::timeout, this, &Worker::refresh);
        m_soon = new QTimer(this);
        m_soon->setSingleShot(true);
        m_soon->setInterval(40);
        connect(m_soon, &QTimer::timeout, this, &Worker::refresh);

        try {
            m_manager = Manager::RequestAsync().get();
        } catch (const winrt::hresult_error& error) {
            qWarning().noquote() << "Windows' media controls are unavailable:" << toQString(error.message());
            return;
        }

        m_sessionsChanged = m_manager.SessionsChanged(winrt::auto_revoke, [this, alive = m_alive](auto&&, auto&&) {
            if (*alive)
                QMetaObject::invokeMethod(this, &Worker::scheduleRefresh, Qt::QueuedConnection);
        });
        m_currentChanged = m_manager.CurrentSessionChanged(winrt::auto_revoke, [this, alive = m_alive](auto&&, auto&&) {
            if (*alive)
                QMetaObject::invokeMethod(this, &Worker::scheduleRefresh, Qt::QueuedConnection);
        });

        m_poll->start();
        refresh();
    }

    void stop() {
        *m_alive = false;
        if (m_poll)
            m_poll->stop();
        if (m_soon)
            m_soon->stop();
        m_sessions.clear();
        m_sessionsChanged.revoke();
        m_currentChanged.revoke();
        m_manager = nullptr;
    }

    void scheduleRefresh() {
        if (m_soon && !m_soon->isActive())
            m_soon->start();
    }

    void togglePlaying(const QString& id) {
        run(id, [](Session& session) {
            const auto info = session.GetPlaybackInfo();
            const auto controls = info.Controls();
            if (controls.IsPlayPauseToggleEnabled())
                session.TryTogglePlayPauseAsync().get();
            else if (info.PlaybackStatus() == Status::Playing)
                session.TryPauseAsync().get();
            else
                session.TryPlayAsync().get();
        });
    }

    void next(const QString& id) {
        run(id, [](Session& session) { session.TrySkipNextAsync().get(); });
    }

    void previous(const QString& id) {
        run(id, [](Session& session) { session.TrySkipPreviousAsync().get(); });
    }

    void seek(const QString& id, double seconds) {
        run(id, [seconds](Session& session) {
            const auto timeline = session.GetTimelineProperties();
            const auto offset = std::chrono::duration_cast<wf::TimeSpan>(std::chrono::duration<double>(seconds));
            session.TryChangePlaybackPositionAsync((timeline.StartTime() + offset).count()).get();
        });
    }

    void setVolume(const QString& id, double volume) {
        const auto it = m_sessions.find(id);
        if (it == m_sessions.end())
            return;
        for (ISimpleAudioVolume* control : m_volumes.find(it->second.app))
            control->SetMasterVolume(float(volume), nullptr);
        scheduleRefresh();
    }

Q_SIGNALS:
    void updated(const QList<MediaSnapshot>& players);

private:
    struct Entry {
        Session session{nullptr};
        QString app;
        Session::MediaPropertiesChanged_revoker mediaChanged;
        Session::PlaybackInfoChanged_revoker playbackChanged;
        Session::TimelinePropertiesChanged_revoker timelineChanged;
        std::shared_ptr<std::atomic<bool>> mediaDirty = std::make_shared<std::atomic<bool>>(true);
        QString trackKey;
        QString title, artist, album, artUrl;
        int artTries = 0;
    };

    template <typename F>
    void run(const QString& id, F&& action) {
        const auto it = m_sessions.find(id);
        if (it == m_sessions.end())
            return;
        try {
            action(it->second.session);
        } catch (const winrt::hresult_error& error) {
            qWarning().noquote() << "Media control failed for" << id << ":" << toQString(error.message());
        }
        scheduleRefresh();
    }

    Entry& hook(const QString& id, const QString& app, const Session& session) {
        Entry& entry = m_sessions[id];
        if (entry.session == session)
            return entry;

        entry = Entry();
        entry.session = session;
        entry.app = app;
        auto alive = m_alive;
        auto dirty = entry.mediaDirty;
        auto soon = [this, alive] {
            if (*alive)
                QMetaObject::invokeMethod(this, &Worker::scheduleRefresh, Qt::QueuedConnection);
        };
        entry.mediaChanged = session.MediaPropertiesChanged(winrt::auto_revoke, [soon, dirty](auto&&, auto&&) {
            *dirty = true;
            soon();
        });
        entry.playbackChanged = session.PlaybackInfoChanged(winrt::auto_revoke, [soon](auto&&, auto&&) { soon(); });
        entry.timelineChanged = session.TimelinePropertiesChanged(winrt::auto_revoke, [soon](auto&&, auto&&) { soon(); });
        return entry;
    }

    static QString readThumbnail(const wss::IRandomAccessStreamReference& reference) {
        if (!reference)
            return QString();
        const auto stream = reference.OpenReadAsync().get();
        const uint64_t size = stream.Size();
        if (size == 0 || size > 16 * 1024 * 1024)
            return QString();
        wss::DataReader reader(stream);
        reader.LoadAsync(uint32_t(size)).get();
        QByteArray bytes(qsizetype(size), Qt::Uninitialized);
        auto* first = reinterpret_cast<uint8_t*>(bytes.data());
        reader.ReadBytes(winrt::array_view<uint8_t>(first, first + size));
        return ArtCache::store(bytes, toQString(stream.ContentType()));
    }

    void readMedia(Entry& entry) {
        const auto media = entry.session.TryGetMediaPropertiesAsync().get();
        const bool dirty = entry.mediaDirty->exchange(false);
        entry.title = toQString(media.Title());
        entry.artist = toQString(media.Artist());
        if (entry.artist.isEmpty())
            entry.artist = toQString(media.AlbumArtist());
        entry.album = toQString(media.AlbumTitle());

        // The cover, read again only when the track changes, the app says
        // something changed (a cover often comes a moment after the
        // title), or there wasn't one yet.
        const QString key = entry.title + QLatin1Char('\n') + entry.artist + QLatin1Char('\n') + entry.album;
        const bool newTrack = key != entry.trackKey;
        if (newTrack) {
            entry.trackKey = key;
            entry.artTries = 0;
        }
        if (newTrack || dirty || (entry.artUrl.isEmpty() && entry.artTries < 3)) {
            entry.artTries++;
            QString art;
            try {
                art = readThumbnail(media.Thumbnail());
            } catch (const winrt::hresult_error&) {
            }
            if (!art.isEmpty() || newTrack)
                entry.artUrl = art;
        }
    }

    MediaSnapshot snapshot(const QString& id, Entry& entry) {
        readMedia(entry);

        MediaSnapshot s;
        s.id = id;
        s.app = entry.app;
        s.title = entry.title;
        s.artist = entry.artist;
        s.album = entry.album;
        s.artUrl = entry.artUrl;

        const auto info = entry.session.GetPlaybackInfo();
        s.playing = info.PlaybackStatus() == Status::Playing;
        const auto controls = info.Controls();
        s.canToggle = controls.IsPlayPauseToggleEnabled() || controls.IsPlayEnabled() || controls.IsPauseEnabled();
        s.canNext = controls.IsNextEnabled();
        s.canPrevious = controls.IsPreviousEnabled();
        s.canSeek = controls.IsPlaybackPositionEnabled();
        if (const auto rate = info.PlaybackRate(); rate && rate.Value() > 0)
            s.rate = rate.Value();

        const auto timeline = entry.session.GetTimelineProperties();
        const double start = toSeconds(timeline.StartTime());
        const double end = toSeconds(timeline.EndTime());
        s.length = end > start ? end - start : 0;
        s.position = std::max(0.0, toSeconds(timeline.Position()) - start);
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        const qint64 at = toMsSinceEpoch(timeline.LastUpdatedTime());
        s.positionAt = at > 0 && at <= now ? at : now;

        const auto volumes = m_volumes.find(entry.app);
        if (!volumes.empty()) {
            float level = 0;
            if (SUCCEEDED(volumes.front()->GetMasterVolume(&level))) {
                s.volumeKnown = true;
                s.volume = level;
            }
        }
        return s;
    }

    void refresh() {
        if (!m_manager)
            return;

        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (now - m_volumesAt >= 1000) {
            m_volumes.refresh();
            m_volumesAt = now;
        }

        QList<MediaSnapshot> players;
        std::set<QString> present;
        try {
            // The session Windows itself thinks is current goes first: with
            // nothing playing and no preference, that's the one shown.
            std::vector<Session> sessions;
            const Session current = m_manager.GetCurrentSession();
            if (current)
                sessions.push_back(current);
            for (const Session& session : m_manager.GetSessions()) {
                if (session != current)
                    sessions.push_back(session);
            }

            std::map<QString, int> seen;
            for (const Session& session : sessions) {
                try {
                    const QString app = toQString(session.SourceAppUserModelId());
                    const int n = seen[app]++;
                    const QString id = n == 0 ? app : app + QLatin1Char('#') + QString::number(n + 1);
                    present.insert(id);
                    players.append(snapshot(id, hook(id, app, session)));
                } catch (const winrt::hresult_error&) {
                    // That app went away mid-read: it's gone next time.
                }
            }
        } catch (const winrt::hresult_error& error) {
            qWarning().noquote() << "Reading the media sessions failed:" << toQString(error.message());
            return;
        }

        for (auto it = m_sessions.begin(); it != m_sessions.end();) {
            if (present.count(it->first))
                ++it;
            else
                it = m_sessions.erase(it);
        }
        Q_EMIT updated(players);
    }

    std::shared_ptr<std::atomic<bool>> m_alive;
    Manager m_manager{nullptr};
    Manager::SessionsChanged_revoker m_sessionsChanged;
    Manager::CurrentSessionChanged_revoker m_currentChanged;
    std::map<QString, Entry> m_sessions;
    AppVolumes m_volumes;
    qint64 m_volumesAt = 0;
    QTimer* m_poll = nullptr;
    QTimer* m_soon = nullptr;
};

class WindowsBackend : public MediaBackend {
public:
    explicit WindowsBackend(QObject* parent)
        : MediaBackend(parent) {
        qRegisterMetaType<MediaSnapshot>();
        qRegisterMetaType<QList<MediaSnapshot>>();
        m_thread.setObjectName(QStringLiteral("media"));
        m_worker.moveToThread(&m_thread);
        connect(&m_thread, &QThread::started, &m_worker, &Worker::start);
        connect(&m_worker, &Worker::updated, this, &MediaBackend::updated);
        m_thread.start();
    }

    ~WindowsBackend() override {
        QMetaObject::invokeMethod(&m_worker, &Worker::stop, Qt::BlockingQueuedConnection);
        m_thread.quit();
        m_thread.wait();
    }

    void togglePlaying(const QString& id) override { post([=, this] { m_worker.togglePlaying(id); }); }
    void next(const QString& id) override { post([=, this] { m_worker.next(id); }); }
    void previous(const QString& id) override { post([=, this] { m_worker.previous(id); }); }
    void seek(const QString& id, double seconds) override { post([=, this] { m_worker.seek(id, seconds); }); }
    void setVolume(const QString& id, double volume) override { post([=, this] { m_worker.setVolume(id, volume); }); }

private:
    template <typename F>
    void post(F&& f) {
        QMetaObject::invokeMethod(&m_worker, std::forward<F>(f), Qt::QueuedConnection);
    }

    QThread m_thread;
    Worker m_worker;
};

} // namespace winmedia

MediaBackend* MediaBackend::create(QObject* parent) {
    if (qEnvironmentVariableIsSet("NOWSPINNING_DEMO"))
        return createDemoBackend(parent);
    return new winmedia::WindowsBackend(parent);
}

#include "media_windows.moc"
