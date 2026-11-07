#include "spectrum.h"

#include <algorithm>
#include <cmath>

namespace {
constexpr double pi = 3.14159265358979323846;
// cava's own range: below 50 Hz there's little but rumble, above 10 kHz
// little that moves with the beat.
constexpr double lowest = 50;
constexpr double highest = 10000;
} // namespace

Spectrum::Spectrum() {
    m_ring.assign(size, 0.0f);
    m_window.resize(size);
    for (std::size_t i = 0; i < size; i++)
        m_window[i] = float(0.5 - 0.5 * std::cos(2 * pi * double(i) / double(size - 1)));

    m_bins.resize(size);
    m_twiddles.resize(size / 2);
    for (std::size_t i = 0; i < size / 2; i++)
        m_twiddles[i] = std::polar(1.0f, float(-2 * pi * double(i) / double(size)));

    m_reversed.resize(size);
    std::size_t bits = 0;
    while ((std::size_t(1) << bits) < size)
        bits++;
    for (std::size_t i = 0; i < size; i++) {
        std::size_t r = 0;
        for (std::size_t b = 0; b < bits; b++)
            if (i & (std::size_t(1) << b))
                r |= std::size_t(1) << (bits - 1 - b);
        m_reversed[i] = r;
    }
}

void Spectrum::configure(int bands, double sampleRate) {
    m_bands = std::max(1, bands);
    m_rate = sampleRate > 0 ? sampleRate : 48000;
    std::fill(m_ring.begin(), m_ring.end(), 0.0f);
    m_out.assign(std::size_t(m_bands), 0.0f);

    // Band edges spaced evenly on a log scale, as the ear hears them, each
    // band at least one bin wide.
    const double top = std::min(highest, m_rate / 2);
    const std::size_t lastBin = size / 2;
    m_edges.resize(std::size_t(m_bands) + 1);
    for (int i = 0; i <= m_bands; i++) {
        const double f = lowest * std::pow(top / lowest, double(i) / m_bands);
        m_edges[std::size_t(i)] = std::size_t(std::lround(f * double(size) / m_rate));
    }
    m_edges[0] = std::max<std::size_t>(1, m_edges[0]);
    for (std::size_t i = 1; i < m_edges.size(); i++)
        m_edges[i] = std::min(lastBin, std::max(m_edges[i], m_edges[i - 1] + 1));
}

void Spectrum::push(const float* samples, std::size_t count) {
    for (std::size_t i = 0; i < count; i++) {
        m_ring[m_write] = samples[i];
        m_write = (m_write + 1) % size;
    }
}

void Spectrum::pushSilence(std::size_t count) {
    count = std::min(count, size);
    for (std::size_t i = 0; i < count; i++) {
        m_ring[m_write] = 0.0f;
        m_write = (m_write + 1) % size;
    }
}

void Spectrum::fft() {
    for (std::size_t i = 0; i < size; i++) {
        const std::size_t j = m_reversed[i];
        if (j > i)
            std::swap(m_bins[i], m_bins[j]);
    }
    for (std::size_t span = 2; span <= size; span <<= 1) {
        const std::size_t half = span / 2;
        const std::size_t step = size / span;
        for (std::size_t start = 0; start < size; start += span) {
            for (std::size_t k = 0; k < half; k++) {
                const std::complex<float> t = m_twiddles[k * step] * m_bins[start + k + half];
                m_bins[start + k + half] = m_bins[start + k] - t;
                m_bins[start + k] += t;
            }
        }
    }
}

std::vector<float> Spectrum::levels(double elapsed) {
    // Oldest sample first, windowed.
    for (std::size_t i = 0; i < size; i++)
        m_bins[i] = {m_ring[(m_write + i) % size] * m_window[i], 0.0f};
    fft();

    // Each band's energy: summed over a band that widens with frequency,
    // music (louder in the lows) comes out about level across the bands.
    // A full scale sine reads about 1.
    const float scale = 4.0f / float(size);
    std::vector<float> raw(static_cast<std::size_t>(m_bands));
    float loudest = 0;
    for (int b = 0; b < m_bands; b++) {
        double energy = 0;
        for (std::size_t k = m_edges[std::size_t(b)]; k < m_edges[std::size_t(b) + 1]; k++)
            energy += double(std::norm(m_bins[k]));
        raw[std::size_t(b)] = float(std::sqrt(energy)) * scale * m_sensitivity;
        loudest = std::max(loudest, raw[std::size_t(b)]);
    }

    // Like cava's autosens: quieter when a band goes past the top, louder,
    // slowly, while there's something to hear and nothing reaches it.
    const double frames = std::max(0.0, elapsed) * 30;
    if (loudest > 1.0f)
        m_sensitivity *= float(std::pow(0.97, frames));
    else if (loudest > 0.02f)
        m_sensitivity *= float(std::pow(1.002, frames));
    m_sensitivity = std::clamp(m_sensitivity, 0.5f, 400.0f);

    // Up fast, down with a little weight, as cava's bars fall.
    const float fall = float(std::pow(0.8, frames));
    for (std::size_t b = 0; b < raw.size(); b++) {
        const float v = std::min(1.0f, raw[b]);
        float& out = m_out[b];
        out = v > out ? out + (v - out) * 0.7f : std::max(v, out * fall);
    }
    return m_out;
}
