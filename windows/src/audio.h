// AudioCapture: the music's levels, band by band, for +windows/AudioLevels.qml.
// On Windows they come from what the default output is playing (WASAPI
// loopback), so there's nothing to install, unlike cava.
#pragma once

#include "spectrum.h"

#include <QObject>
#include <QQmlParserStatus>
#include <QThread>
#include <QVariantList>

#include <memory>
#include <vector>

// The sound going out to the speakers, mono. One per system.
class LoopbackSource {
public:
    virtual ~LoopbackSource() = default;

    // Starts listening to the default output. False when there's none.
    virtual bool open() = 0;
    virtual void close() = 0;
    virtual double sampleRate() const = 0;
    // Appends what came in since the last call. False when the device is
    // gone and it has to be opened again.
    virtual bool read(std::vector<float>& out) = 0;
    // The default output is another one now.
    virtual bool defaultChanged() { return false; }

    static std::unique_ptr<LoopbackSource> create();
};

class AudioWorker : public QObject {
    Q_OBJECT

public:
    void start(int bands);
    void stop();

Q_SIGNALS:
    void levels(const QVariantList& levels);

private:
    void tick();
    bool reopen();

    std::unique_ptr<LoopbackSource> m_source;
    Spectrum m_spectrum;
    std::vector<float> m_buffer;
    class QTimer* m_timer = nullptr;
    int m_bands = 16;
    bool m_open = false;
    qint64 m_lastTry = 0;
    qint64 m_lastCheck = 0;
    qint64 m_lastData = 0;
    qint64 m_lastLevels = 0;
};

class AudioCapture : public QObject, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int bands READ bands WRITE setBands NOTIFY bandsChanged)
    Q_PROPERTY(QVariantList levels READ levels NOTIFY levelsChanged)

public:
    explicit AudioCapture(QObject* parent = nullptr);
    ~AudioCapture() override;

    void classBegin() override {}
    void componentComplete() override;

    bool active() const { return m_active; }
    void setActive(bool active);
    int bands() const { return m_bands; }
    void setBands(int bands);
    // Empty while not listening, or with nothing to listen to: the wave
    // then falls back to its plain sine.
    QVariantList levels() const { return m_levels; }

Q_SIGNALS:
    void activeChanged();
    void bandsChanged();
    void levelsChanged();

private:
    void restart();
    void setLevels(const QVariantList& levels);

    bool m_complete = false;
    bool m_active = false;
    int m_bands = 16;
    QVariantList m_levels;
    QThread* m_thread = nullptr;
    AudioWorker* m_worker = nullptr;
    int m_generation = 0;
};
