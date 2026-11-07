// Quickshell's windows, on a plain Qt window: PanelWindow (the widget and
// its lyrics) and PopupWindow (the settings card), and the layer-shell
// properties set on them (`WlrLayershell.layer`).
//
// Under Quickshell a PanelWindow is a layer-shell surface, placed by the
// compositor from its anchors and margins. Here it's a frameless,
// translucent tool window (no taskbar button, never takes the focus)
// placed at the same spot by hand: anchored top and left, its margins are
// its distance from the screen's top left corner. The layer becomes
// always on top ("overlay" and "top") or always at the bottom ("bottom").
// A mask works as under Wayland: outside it, clicks go through to
// whatever's behind the window.
#pragma once

#include "quickshell.h"

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRectF>
#include <QTimer>
#include <QtQml/qqml.h>

// Shared by both kinds of window: what's inside, size, colour, visibility,
// screen, and the input mask.
class ProxyWindow : public QObject, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool visible READ isVisible WRITE setVisible NOTIFY visibleChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal implicitWidth READ implicitWidth WRITE setImplicitWidth NOTIFY implicitWidthChanged)
    Q_PROPERTY(qreal implicitHeight READ implicitHeight WRITE setImplicitHeight NOTIFY implicitHeightChanged)
    Q_PROPERTY(qreal width READ width WRITE setWidth NOTIFY widthChanged)
    Q_PROPERTY(qreal height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(ShellScreen* screen READ screen WRITE setScreen NOTIFY screenChanged)
    Q_PROPERTY(Region* mask READ mask WRITE setMask NOTIFY maskChanged)
    Q_PROPERTY(QQuickItem* contentItem READ contentItem CONSTANT)
    Q_PROPERTY(QQuickWindow* window READ window CONSTANT)
    Q_PROPERTY(QQmlListProperty<QObject> data READ data)
    Q_CLASSINFO("DefaultProperty", "data")

public:
    explicit ProxyWindow(QObject* parent = nullptr);
    ~ProxyWindow() override;

    void classBegin() override {}
    void componentComplete() override;

    bool isVisible() const { return m_visible; }
    void setVisible(bool visible);
    QColor color() const { return m_color; }
    void setColor(const QColor& color);
    qreal implicitWidth() const { return m_implicitWidth; }
    void setImplicitWidth(qreal width);
    qreal implicitHeight() const { return m_implicitHeight; }
    void setImplicitHeight(qreal height);
    qreal width() const;
    void setWidth(qreal width);
    qreal height() const;
    void setHeight(qreal height);
    // The screen it's on: the one given, or with none given, the one it
    // picked when it first showed. Never null once there's a screen.
    ShellScreen* screen() const;
    void setScreen(ShellScreen* screen);
    Region* mask() const { return m_mask; }
    void setMask(Region* mask);
    QQuickItem* contentItem() const;
    QQuickWindow* window() const { return m_window; }
    QQmlListProperty<QObject> data();

    // "overlay" and "top" keep it above other windows, "bottom" below.
    void setLayer(int layer);
    int layer() const { return m_layer; }
    // The window's title: what Windows' own tools list it as.
    void setTitle(const QString& title);

Q_SIGNALS:
    void visibleChanged();
    void colorChanged();
    void implicitWidthChanged();
    void implicitHeightChanged();
    void widthChanged();
    void heightChanged();
    void screenChanged();
    void maskChanged();
    // The window moved or changed size, on screen.
    void geometryChanged();

protected:
    // Where the window goes, in global coordinates, at its current size.
    virtual QRect targetGeometry() const = 0;
    virtual Qt::WindowFlags extraFlags() const { return {}; }
    // Puts the window where targetGeometry() says. Coalesced: several
    // property changes in a row move it once.
    void scheduleGeometry();
    void applyGeometry();
    void applyFlags();
    void applyVisible();
    QSize size() const;
    bool complete() const { return m_complete; }

private:
    void updateInput();
    void setClickThrough(bool through);

    static void appendData(QQmlListProperty<QObject>* list, QObject* object);
    static qsizetype dataCount(QQmlListProperty<QObject>* list);
    static QObject* dataAt(QQmlListProperty<QObject>* list, qsizetype index);
    static void clearData(QQmlListProperty<QObject>* list);

    QQuickWindow* m_window;
    bool m_complete = false;
    bool m_visible = true;
    QColor m_color = Qt::white;
    qreal m_implicitWidth = 0;
    qreal m_implicitHeight = 0;
    qreal m_width = -1;
    qreal m_height = -1;
    QPointer<ShellScreen> m_screen;
    QPointer<ShellScreen> m_pickedScreen;
    QPointer<Region> m_mask;
    int m_layer = 2; // WlrLayer::Top, as under Quickshell
    bool m_geometryPending = false;
    QRect m_lastGeometry;
    QTimer m_inputPoll;
    bool m_clickThrough = false;
    bool m_clickThroughKnown = false;
    bool m_nativeClickThrough = false;
};

class Anchors : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool top MEMBER m_top NOTIFY changed)
    Q_PROPERTY(bool bottom MEMBER m_bottom NOTIFY changed)
    Q_PROPERTY(bool left MEMBER m_left NOTIFY changed)
    Q_PROPERTY(bool right MEMBER m_right NOTIFY changed)
    QML_ANONYMOUS

public:
    using QObject::QObject;
    bool m_top = false, m_bottom = false, m_left = false, m_right = false;

Q_SIGNALS:
    void changed();
};

class Margins : public QObject {
    Q_OBJECT
    Q_PROPERTY(int top MEMBER m_top NOTIFY changed)
    Q_PROPERTY(int bottom MEMBER m_bottom NOTIFY changed)
    Q_PROPERTY(int left MEMBER m_left NOTIFY changed)
    Q_PROPERTY(int right MEMBER m_right NOTIFY changed)
    QML_ANONYMOUS

public:
    using QObject::QObject;
    int m_top = 0, m_bottom = 0, m_left = 0, m_right = 0;

Q_SIGNALS:
    void changed();
};

class PanelWindow : public ProxyWindow {
    Q_OBJECT
    Q_PROPERTY(Anchors* anchors READ anchors CONSTANT)
    Q_PROPERTY(Margins* margins READ margins CONSTANT)
    Q_PROPERTY(int exclusionMode READ exclusionMode WRITE setExclusionMode NOTIFY exclusionModeChanged)
    Q_PROPERTY(int exclusiveZone READ exclusiveZone WRITE setExclusiveZone NOTIFY exclusiveZoneChanged)
    Q_PROPERTY(bool focusable READ focusable WRITE setFocusable NOTIFY focusableChanged)

public:
    explicit PanelWindow(QObject* parent = nullptr);

    Anchors* anchors() const { return m_anchors; }
    Margins* margins() const { return m_margins; }
    int exclusionMode() const { return m_exclusionMode; }
    void setExclusionMode(int mode);
    int exclusiveZone() const { return m_exclusiveZone; }
    void setExclusiveZone(int zone);
    bool focusable() const { return m_focusable; }
    void setFocusable(bool focusable);

Q_SIGNALS:
    void exclusionModeChanged();
    void exclusiveZoneChanged();
    void focusableChanged();

protected:
    QRect targetGeometry() const override;

private:
    Anchors* m_anchors;
    Margins* m_margins;
    int m_exclusionMode = 0;
    int m_exclusiveZone = 0;
    bool m_focusable = false;
};

// The rectangle a popup is anchored to, in its parent window's coordinates.
class AnchorRect : public QObject {
    Q_OBJECT
    Q_PROPERTY(qreal x MEMBER m_x NOTIFY changed)
    Q_PROPERTY(qreal y MEMBER m_y NOTIFY changed)
    Q_PROPERTY(qreal width MEMBER m_width NOTIFY changed)
    Q_PROPERTY(qreal height MEMBER m_height NOTIFY changed)
    QML_ANONYMOUS

public:
    using QObject::QObject;
    qreal m_x = 0, m_y = 0, m_width = 0, m_height = 0;

Q_SIGNALS:
    void changed();
};

class PopupAnchor : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* window READ window WRITE setWindow NOTIFY changed)
    Q_PROPERTY(AnchorRect* rect READ rect CONSTANT)
    Q_PROPERTY(int edges MEMBER m_edges NOTIFY changed)
    Q_PROPERTY(int gravity MEMBER m_gravity NOTIFY changed)
    Q_PROPERTY(int adjustment MEMBER m_adjustment NOTIFY changed)
    QML_ANONYMOUS

public:
    explicit PopupAnchor(QObject* parent);

    QObject* window() const { return m_window; }
    void setWindow(QObject* window);
    AnchorRect* rect() const { return m_rect; }

    // Places the popup again, now: after the parent window moved or
    // changed size, say.
    Q_INVOKABLE void updateAnchor();

    int m_edges = 0;
    int m_gravity = 0;
    int m_adjustment = 0;

Q_SIGNALS:
    void changed();
    void anchoring();

private:
    QPointer<QObject> m_window;
    AnchorRect* m_rect;
};

class PopupWindow : public ProxyWindow {
    Q_OBJECT
    Q_PROPERTY(PopupAnchor* anchor READ anchor CONSTANT)

public:
    explicit PopupWindow(QObject* parent = nullptr);
    void componentComplete() override;

    PopupAnchor* anchor() const { return m_anchor; }

protected:
    QRect targetGeometry() const override;

private:
    void followParent();

    PopupAnchor* m_anchor;
    QPointer<ProxyWindow> m_parentWindow;
};

namespace WlrLayer {
Q_NAMESPACE
enum Enum { Background = 0, Bottom = 1, Top = 2, Overlay = 3 };
Q_ENUM_NS(Enum)
} // namespace WlrLayer

namespace WlrKeyboardFocus {
Q_NAMESPACE
enum Enum { None = 0, Exclusive = 1, OnDemand = 2 };
Q_ENUM_NS(Enum)
} // namespace WlrKeyboardFocus

// `WlrLayershell.layer` and `WlrLayershell.namespace`, attached to a
// PanelWindow.
class WlrLayershell : public QObject {
    Q_OBJECT
    Q_PROPERTY(int layer READ layer WRITE setLayer NOTIFY layerChanged)
    Q_PROPERTY(QString namespace READ ns WRITE setNs NOTIFY nsChanged)
    Q_PROPERTY(int keyboardFocus MEMBER m_keyboardFocus NOTIFY keyboardFocusChanged)
    QML_ATTACHED(WlrLayershell)

public:
    explicit WlrLayershell(QObject* parent = nullptr);
    static WlrLayershell* qmlAttachedProperties(QObject* object);

    int layer() const { return m_layer; }
    void setLayer(int layer);
    QString ns() const { return m_ns; }
    void setNs(const QString& ns);

Q_SIGNALS:
    void layerChanged();
    void nsChanged();
    void keyboardFocusChanged();

private:
    QPointer<ProxyWindow> m_window;
    int m_layer = WlrLayer::Top;
    QString m_ns = QStringLiteral("quickshell");
    int m_keyboardFocus = WlrKeyboardFocus::None;
};
