#include "host.h"

#include "audio.h"
#include "io.h"
#include "mpris.h"
#include "panelwindow.h"
#include "quickshell.h"

#include <QCursor>
#include <QtQml/qqml.h>

QPointF HostCursor::position() const {
    return QCursor::pos();
}

namespace Host {

namespace {
const char* const notCreatable = "made by NowSpinning, not in QML";

void registerQuickshell(QuickshellGlobal* global) {
    // Each of the modules can read `Quickshell`, as when imported through
    // Quickshell's own.
    for (const char* uri : {"Quickshell", "Quickshell.Io", "Quickshell.Wayland", "Quickshell.Widgets"})
        qmlRegisterSingletonInstance(uri, 1, 0, "Quickshell", global);

    const char* uri = "Quickshell";
    qmlRegisterType(QUrl(QStringLiteral("qrc:/shim/ShellRoot.qml")), uri, 1, 0, "ShellRoot");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/shim/ShellRoot.qml")), uri, 1, 0, "Scope");
    qmlRegisterType<PanelWindow>(uri, 1, 0, "PanelWindow");
    qmlRegisterType<PopupWindow>(uri, 1, 0, "PopupWindow");
    qmlRegisterType<Region>(uri, 1, 0, "Region");
    qmlRegisterUncreatableType<ShellScreen>(uri, 1, 0, "ShellScreen", notCreatable);
    qmlRegisterUncreatableType<ProxyWindow>(uri, 1, 0, "QsWindow", notCreatable);
    qmlRegisterAnonymousType<Anchors>(uri, 1);
    qmlRegisterAnonymousType<Margins>(uri, 1);
    qmlRegisterAnonymousType<PopupAnchor>(uri, 1);
    qmlRegisterAnonymousType<AnchorRect>(uri, 1);
    qmlRegisterUncreatableMetaObject(RegionShape::staticMetaObject, uri, 1, 0, "RegionShape", notCreatable);
    qmlRegisterUncreatableMetaObject(Intersection::staticMetaObject, uri, 1, 0, "Intersection", notCreatable);
    qmlRegisterUncreatableMetaObject(Edges::staticMetaObject, uri, 1, 0, "Edges", notCreatable);
    qmlRegisterUncreatableMetaObject(PopupAdjustment::staticMetaObject, uri, 1, 0, "PopupAdjustment", notCreatable);
    qmlRegisterUncreatableMetaObject(ExclusionMode::staticMetaObject, uri, 1, 0, "ExclusionMode", notCreatable);

    uri = "Quickshell.Wayland";
    qmlRegisterUncreatableType<WlrLayershell>(uri, 1, 0, "WlrLayershell", notCreatable);
    qmlRegisterUncreatableMetaObject(WlrLayer::staticMetaObject, uri, 1, 0, "WlrLayer", notCreatable);
    qmlRegisterUncreatableMetaObject(WlrKeyboardFocus::staticMetaObject, uri, 1, 0, "WlrKeyboardFocus", notCreatable);

    uri = "Quickshell.Io";
    qmlRegisterType<FileView>(uri, 1, 0, "FileView");
    qmlRegisterType<JsonAdapter>(uri, 1, 0, "JsonAdapter");
    qmlRegisterType<Process>(uri, 1, 0, "Process");

    uri = "Quickshell.Widgets";
    qmlRegisterType(QUrl(QStringLiteral("qrc:/shim/ClippingRectangle.qml")), uri, 1, 0, "ClippingRectangle");

    uri = "Quickshell.Services.Mpris";
    qmlRegisterSingletonInstance(uri, 1, 0, "Mpris", new Mpris(global));
    qmlRegisterUncreatableType<MprisPlayer>(uri, 1, 0, "MprisPlayer", notCreatable);
    qmlRegisterAnonymousType<MprisPlayers>(uri, 1);
}
} // namespace

void registerTypes() {
    auto* global = new QuickshellGlobal();
    registerQuickshell(global);

    const char* uri = "NowSpinning.Host";
    qmlRegisterSingletonInstance(uri, 1, 0, "Cursor", new HostCursor(global));
    qmlRegisterType<AudioCapture>(uri, 1, 0, "AudioCapture");
}

} // namespace Host
