#include "audio.h"

#include <QDateTime>
#include <QTimer>

namespace {
// Read every 15 ms, levels out every 33: thirty a second, as cava sends.
constexpr int readMs = 15;
constexpr int levelsMs = 33;
// The default output can change under it (headphones plugged in).
constexpr int checkMs = 2000;
// With no device, tried again this often.
constexpr int retryMs = 3000;
} // namespace

void AudioWorker::start(int bands) {
    m_bands = bands;
    if (!m_source)
        m_source = LoopbackSource::create();
    if (!m_timer) {
        m_timer = new QTimer(this);
        m_timer->setInterval(readMs);
        connect(m_timer, &QTimer::timeout, this, &AudioWorker::tick);
    }
    m_lastTry = 0;
    m_timer->start();
    tick();
}

void AudioWorker::stop() {
    if (m_timer)
        m_timer->stop();
    if (m_source && m_open)
        m_source->close();
    m_open = false;
    m_source.reset();
}

bool AudioWorker::reopen() {
    if (m_open)
        m_source->close();
    m_open = m_source && m_source->open();
    if (m_open) {
        m_spectrum.configure(m_bands, m_source->sampleRate());
        m_lastData = m_lastLevels = QDateTime::currentMSecsSinceEpoch();
    }
    return m_open;
}

void AudioWorker::tick() {
    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    if (!m_open) {
        if (now - m_lastTry < retryMs)
            return;
        m_lastTry = now;
        m_lastCheck = now;
        if (!reopen())
            return;
    }

    if (now - m_lastCheck >= checkMs) {
        m_lastCheck = now;
        if (m_source->defaultChanged() && !reopen())
            return;
    }

    m_buffer.clear();
    if (!m_source->read(m_buffer)) {
        m_source->close();
        m_open = false;
        m_lastTry = 0;
        Q_EMIT levels({});
        return;
    }
    if (!m_buffer.empty()) {
        m_spectrum.push(m_buffer.data(), m_buffer.size());
        m_lastData = now;
    } else if (now - m_lastData > 3 * readMs) {
        // Nothing playing: Windows sends nothing at all, not zeros.
        m_spectrum.pushSilence(std::size_t(m_source->sampleRate() * readMs / 1000.0));
    }

    if (now - m_lastLevels >= levelsMs) {
        const std::vector<float> out = m_spectrum.levels((now - m_lastLevels) / 1000.0);
        m_lastLevels = now;
        QVariantList list;
        list.reserve(qsizetype(out.size()));
        for (float v : out)
            list.append(double(v));
        Q_EMIT levels(list);
    }
}

AudioCapture::AudioCapture(QObject* parent)
    : QObject(parent) {}

AudioCapture::~AudioCapture() {
    m_active = false;
    restart();
}

void AudioCapture::componentComplete() {
    m_complete = true;
    restart();
}

void AudioCapture::setActive(bool active) {
    if (active == m_active)
        return;
    m_active = active;
    Q_EMIT activeChanged();
    restart();
}

void AudioCapture::setBands(int bands) {
    if (bands == m_bands || bands <= 0)
        return;
    m_bands = bands;
    Q_EMIT bandsChanged();
    restart();
}

// Listens only while active, on a thread of its own; stopping drops the
// levels, as the widget expects when cava stops.
void AudioCapture::restart() {
    ++m_generation;
    if (m_thread) {
        QMetaObject::invokeMethod(m_worker, &AudioWorker::stop, Qt::BlockingQueuedConnection);
        m_thread->quit();
        m_thread->wait();
        delete m_worker;
        delete m_thread;
        m_worker = nullptr;
        m_thread = nullptr;
    }
    if (m_complete)
        setLevels({});
    if (!m_complete || !m_active)
        return;

    m_thread = new QThread();
    m_thread->setObjectName(QStringLiteral("audio"));
    m_worker = new AudioWorker();
    m_worker->moveToThread(m_thread);
    // Levels still on their way from a worker since stopped don't count.
    const int generation = ++m_generation;
    connect(m_worker, &AudioWorker::levels, this, [this, generation](const QVariantList& levels) {
        if (generation == m_generation)
            setLevels(levels);
    });
    const int bands = m_bands;
    connect(m_thread, &QThread::started, m_worker, [worker = m_worker, bands] { worker->start(bands); });
    m_thread->start();
}

void AudioCapture::setLevels(const QVariantList& levels) {
    if (levels.isEmpty() && m_levels.isEmpty())
        return;
    m_levels = levels;
    Q_EMIT levelsChanged();
}
