// Players elsewhere than Windows: none of its own (under Linux, Quickshell
// runs the widget, not this program), only the demo with NOWSPINNING_DEMO.
#include "media.h"

MediaBackend* createDemoBackend(QObject* parent);

namespace {
class NoBackend : public MediaBackend {
public:
    using MediaBackend::MediaBackend;
    void togglePlaying(const QString&) override {}
    void next(const QString&) override {}
    void previous(const QString&) override {}
    void seek(const QString&, double) override {}
    void setVolume(const QString&, double) override {}
};
} // namespace

MediaBackend* MediaBackend::create(QObject* parent) {
    if (qEnvironmentVariableIsSet("NOWSPINNING_DEMO"))
        return createDemoBackend(parent);
    return new NoBackend(parent);
}
