// The sound on its way to the speakers, through WASAPI's loopback: what
// cava reads from PipeWire on Linux. Listens to the default output in
// shared mode, so it takes nothing from anyone, and needs no permission.
#include "audio.h"

#include <QtDebug>

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>

#include <cstring>

namespace {

template <typename T>
void release(T*& p) {
    if (p) {
        p->Release();
        p = nullptr;
    }
}

class WasapiLoopback : public LoopbackSource {
public:
    WasapiLoopback() {
        const HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        m_comInitialized = SUCCEEDED(hr);
    }

    ~WasapiLoopback() override {
        close();
        release(m_devices);
        if (m_comInitialized)
            CoUninitialize();
    }

    bool open() override {
        close();
        if (!m_devices && FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                                  __uuidof(IMMDeviceEnumerator), reinterpret_cast<void**>(&m_devices))))
            return false;

        IMMDevice* device = nullptr;
        if (FAILED(m_devices->GetDefaultAudioEndpoint(eRender, eMultimedia, &device)))
            return false;
        m_deviceId = idOf(device);
        HRESULT hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, reinterpret_cast<void**>(&m_client));
        release(device);
        if (FAILED(hr))
            return false;

        WAVEFORMATEX* format = nullptr;
        if (FAILED(m_client->GetMixFormat(&format))) {
            close();
            return false;
        }
        m_channels = format->nChannels;
        m_rate = format->nSamplesPerSec;
        m_bits = format->wBitsPerSample;
        m_blockAlign = format->nBlockAlign;
        WORD tag = format->wFormatTag;
        if (tag == WAVE_FORMAT_EXTENSIBLE && format->cbSize >= 22)
            tag = WORD(reinterpret_cast<WAVEFORMATEXTENSIBLE*>(format)->SubFormat.Data1);
        m_float = tag == WAVE_FORMAT_IEEE_FLOAT;
        const bool pcm = tag == WAVE_FORMAT_PCM && (m_bits == 16 || m_bits == 24 || m_bits == 32);

        // 200 ms of buffer: read every 15, room to spare.
        hr = (m_float || pcm) && m_channels > 0
            ? m_client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, 2000000, 0, format, nullptr)
            : E_FAIL;
        CoTaskMemFree(format);
        if (FAILED(hr)
            || FAILED(m_client->GetService(__uuidof(IAudioCaptureClient), reinterpret_cast<void**>(&m_capture)))
            || FAILED(m_client->Start())) {
            close();
            return false;
        }
        return true;
    }

    void close() override {
        if (m_client)
            m_client->Stop();
        release(m_capture);
        release(m_client);
    }

    double sampleRate() const override { return m_rate; }

    bool read(std::vector<float>& out) override {
        if (!m_capture)
            return false;
        UINT32 packet = 0;
        HRESULT hr;
        while (SUCCEEDED(hr = m_capture->GetNextPacketSize(&packet)) && packet > 0) {
            BYTE* data = nullptr;
            UINT32 frames = 0;
            DWORD flags = 0;
            hr = m_capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr);
            if (FAILED(hr))
                return false;
            const std::size_t start = out.size();
            out.resize(start + frames);
            if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
                std::fill(out.begin() + qsizetype(start), out.end(), 0.0f);
            } else {
                for (UINT32 f = 0; f < frames; f++)
                    out[start + f] = mono(data + std::size_t(f) * m_blockAlign);
            }
            m_capture->ReleaseBuffer(frames);
        }
        return SUCCEEDED(hr);
    }

    bool defaultChanged() override {
        if (!m_devices)
            return false;
        IMMDevice* device = nullptr;
        if (FAILED(m_devices->GetDefaultAudioEndpoint(eRender, eMultimedia, &device)))
            return true;
        const std::wstring id = idOf(device);
        release(device);
        return id != m_deviceId;
    }

private:
    static std::wstring idOf(IMMDevice* device) {
        LPWSTR id = nullptr;
        std::wstring result;
        if (SUCCEEDED(device->GetId(&id)) && id) {
            result = id;
            CoTaskMemFree(id);
        }
        return result;
    }

    // One frame, every channel averaged, -1..1.
    float mono(const BYTE* frame) const {
        float sum = 0;
        for (int c = 0; c < m_channels; c++) {
            const BYTE* p = frame + std::size_t(c) * (m_bits / 8);
            float v = 0;
            if (m_float) {
                std::memcpy(&v, p, sizeof(float));
            } else if (m_bits == 16) {
                int16_t s;
                std::memcpy(&s, p, sizeof s);
                v = s / 32768.0f;
            } else if (m_bits == 24) {
                const int32_t s = int32_t(uint32_t(p[0]) << 8 | uint32_t(p[1]) << 16 | uint32_t(p[2]) << 24) >> 8;
                v = s / 8388608.0f;
            } else {
                int32_t s;
                std::memcpy(&s, p, sizeof s);
                v = float(s / 2147483648.0);
            }
            sum += v;
        }
        return sum / float(m_channels);
    }

    bool m_comInitialized = false;
    IMMDeviceEnumerator* m_devices = nullptr;
    IAudioClient* m_client = nullptr;
    IAudioCaptureClient* m_capture = nullptr;
    std::wstring m_deviceId;
    int m_channels = 0;
    int m_bits = 0;
    int m_blockAlign = 0;
    double m_rate = 48000;
    bool m_float = true;
};

} // namespace

std::unique_ptr<LoopbackSource> LoopbackSource::create() {
    return std::make_unique<WasapiLoopback>();
}
