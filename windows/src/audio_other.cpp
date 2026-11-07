// Sound elsewhere than Windows: nothing to listen to (under Linux,
// Quickshell and cava do this), unless NOWSPINNING_DEMO is set, which plays
// a made-up beat, so the levels can be tried without a real output.
#include "audio.h"

#include <QElapsedTimer>

#include <cmath>
#include <random>

namespace {

class DemoBeat : public LoopbackSource {
public:
    bool open() override {
        m_clock.start();
        m_made = 0;
        return true;
    }
    void close() override {}
    double sampleRate() const override { return 48000; }

    bool read(std::vector<float>& out) override {
        const qint64 due = m_clock.nsecsElapsed() * 48 / 1000000;
        for (; m_made < due; m_made++) {
            const double t = m_made / 48000.0;
            const double beat = std::fmod(t, 0.5);
            const double kick = std::exp(-beat * 18) * std::sin(2 * M_PI * (55 + 60 * std::exp(-beat * 30)) * beat);
            const double bass = 0.25 * std::sin(2 * M_PI * (std::fmod(t, 2) < 1 ? 82.4 : 110) * t);
            const double chord = 0.08 * (std::sin(2 * M_PI * 440 * t) + std::sin(2 * M_PI * 554.4 * t));
            const double hat = std::fmod(t + 0.25, 0.5) < 0.03 ? 0.15 * (m_noise(m_random) - 0.5) : 0;
            out.push_back(float(0.6 * kick + bass + chord + hat));
        }
        return true;
    }

private:
    QElapsedTimer m_clock;
    qint64 m_made = 0;
    std::mt19937 m_random{7};
    std::uniform_real_distribution<double> m_noise{0, 1};
};

class Nothing : public LoopbackSource {
public:
    bool open() override { return false; }
    void close() override {}
    double sampleRate() const override { return 48000; }
    bool read(std::vector<float>&) override { return false; }
};

} // namespace

std::unique_ptr<LoopbackSource> LoopbackSource::create() {
    if (qEnvironmentVariableIsSet("NOWSPINNING_DEMO"))
        return std::make_unique<DemoBeat>();
    return std::make_unique<Nothing>();
}
