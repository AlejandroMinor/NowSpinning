// What nowspinning.exe adds to QML: the Quickshell modules the widget
// imports, and NowSpinning.Host, for the few QML files under
// nowspinning/+windows that take the place of Linux-only ones.
#pragma once

#include <QObject>
#include <QPointF>

// `Cursor.position()`: where the pointer is on the desktop, the same
// coordinates screens and windows are placed in. What Hyprland's socket
// answers on Linux while dragging.
class HostCursor : public QObject {
    Q_OBJECT

public:
    using QObject::QObject;
    Q_INVOKABLE QPointF position() const;
};

namespace Host {
void registerTypes();
}
