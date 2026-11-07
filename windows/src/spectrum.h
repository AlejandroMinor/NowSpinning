// What cava does for the widget on Linux: how loud each band of the music
// is, lows first, 0..1, about thirty times a second. Fed the sound itself,
// mono; it keeps the last few thousand samples and turns them into
// levels on each call.
#pragma once

#include <complex>
#include <cstddef>
#include <vector>

class Spectrum {
public:
    Spectrum();

    void configure(int bands, double sampleRate);
    void push(const float* samples, std::size_t count);
    // Zeros, for time that passed with nothing to hear: Windows sends no
    // sound at all while nothing plays, and the last bars mustn't hang on.
    void pushSilence(std::size_t count);
    // The levels now, `elapsed` seconds after the last call.
    std::vector<float> levels(double elapsed);

    int bands() const { return m_bands; }

private:
    static constexpr std::size_t size = 2048;

    void fft();

    int m_bands = 0;
    double m_rate = 48000;
    std::vector<float> m_ring;
    std::size_t m_write = 0;
    std::vector<float> m_window;
    std::vector<std::complex<float>> m_bins;
    std::vector<std::complex<float>> m_twiddles;
    std::vector<std::size_t> m_reversed;
    std::vector<std::size_t> m_edges;
    std::vector<float> m_out;
    float m_sensitivity = 8;
};
