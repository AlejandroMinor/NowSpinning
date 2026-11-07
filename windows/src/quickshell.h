// The parts of Quickshell's own module (`import Quickshell`) the widget
// uses: its screens, its environment, and the regions and enums its
// windows take. Same names and the same meaning, so the QML reads the same
// here as under Quickshell.
#pragma once

#include <QObject>
#include <QPointF>
#include <QQmlListProperty>
#include <QRect>
#include <QVariant>
#include <QVariantList>

class QScreen;

// One monitor. x, y, width and height are its work area, the part the
// taskbar leaves free: on Windows that's what a widget lines up against,
// the way it lines up against the whole output on Hyprland. `name` is the
// monitor's own, DISPLAY1, DISPLAY2..., for config.json's `monitor`.
class ShellScreen : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString model READ model CONSTANT)
    Q_PROPERTY(int x READ x NOTIFY geometryChanged)
    Q_PROPERTY(int y READ y NOTIFY geometryChanged)
    Q_PROPERTY(int width READ width NOTIFY geometryChanged)
    Q_PROPERTY(int height READ height NOTIFY geometryChanged)
    Q_PROPERTY(qreal devicePixelRatio READ devicePixelRatio NOTIFY geometryChanged)

public:
    ShellScreen(QScreen* screen, QObject* parent);

    QScreen* screen() const { return m_screen; }
    QRect geometry() const;

    QString name() const;
    QString model() const;
    int x() const { return geometry().x(); }
    int y() const { return geometry().y(); }
    int width() const { return geometry().width(); }
    int height() const { return geometry().height(); }
    qreal devicePixelRatio() const;

Q_SIGNALS:
    void geometryChanged();

private:
    QScreen* m_screen;
};

// The `Quickshell` singleton: `Quickshell.screens`, `Quickshell.env(...)`.
class QuickshellGlobal : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList screens READ screens NOTIFY screensChanged)

public:
    explicit QuickshellGlobal(QObject* parent = nullptr);
    static QuickshellGlobal* instance();

    QVariantList screens() const;
    ShellScreen* screenFor(QScreen* screen) const;
    // The screen under the pointer: where a window with no screen of its
    // own appears, the way a compositor puts it on the focused output.
    ShellScreen* screenAtCursor() const;

    // An unset variable is null, not "", like under Quickshell, so
    // `Quickshell.env("X") || fallback` works the same.
    Q_INVOKABLE QVariant env(const QString& name) const;

Q_SIGNALS:
    void screensChanged();

private:
    void addScreen(QScreen* screen);
    void removeScreen(QScreen* screen);

    QList<ShellScreen*> m_screens;
};

namespace RegionShape {
Q_NAMESPACE
enum Enum { Rect = 0, Ellipse = 1 };
Q_ENUM_NS(Enum)
} // namespace RegionShape

namespace Intersection {
Q_NAMESPACE
enum Enum { Combine = 0, Subtract = 1, Intersect = 2, Xor = 3 };
Q_ENUM_NS(Enum)
} // namespace Intersection

// A window's input region: a rectangle or an ellipse, and the regions
// inside `regions` combined with it. A window with a mask only takes the
// pointer inside it; elsewhere clicks go through to what's behind.
class Region : public QObject {
    Q_OBJECT
    Q_PROPERTY(int shape READ shape WRITE setShape NOTIFY changed)
    Q_PROPERTY(int intersection READ intersection WRITE setIntersection NOTIFY changed)
    Q_PROPERTY(qreal x READ x WRITE setX NOTIFY changed)
    Q_PROPERTY(qreal y READ y WRITE setY NOTIFY changed)
    Q_PROPERTY(qreal width READ width WRITE setWidth NOTIFY changed)
    Q_PROPERTY(qreal height READ height WRITE setHeight NOTIFY changed)
    Q_PROPERTY(QQmlListProperty<Region> regions READ regions NOTIFY changed)
    Q_CLASSINFO("DefaultProperty", "regions")

public:
    explicit Region(QObject* parent = nullptr);

    int shape() const { return m_shape; }
    void setShape(int shape);
    int intersection() const { return m_intersection; }
    void setIntersection(int intersection);
    qreal x() const { return m_rect.x(); }
    void setX(qreal x);
    qreal y() const { return m_rect.y(); }
    void setY(qreal y);
    qreal width() const { return m_rect.width(); }
    void setWidth(qreal width);
    qreal height() const { return m_rect.height(); }
    void setHeight(qreal height);
    QQmlListProperty<Region> regions();

    // Whether a point, in the window's coordinates, takes the pointer.
    bool contains(const QPointF& point) const;
    // Takes no point at all: `Region {}`, a window clicks go through.
    bool isEmpty() const;

Q_SIGNALS:
    void changed();

private:
    bool ownContains(const QPointF& point) const;

    static void appendRegion(QQmlListProperty<Region>* list, Region* region);
    static qsizetype regionCount(QQmlListProperty<Region>* list);
    static Region* regionAt(QQmlListProperty<Region>* list, qsizetype index);
    static void clearRegions(QQmlListProperty<Region>* list);

    int m_shape = RegionShape::Rect;
    int m_intersection = Intersection::Combine;
    QRectF m_rect;
    QList<Region*> m_regions;
};

// Edges of a rectangle, for a popup's anchor and gravity.
namespace Edges {
Q_NAMESPACE
enum Enum { None = 0, Top = 1, Left = 2, Right = 4, Bottom = 8 };
Q_ENUM_NS(Enum)
} // namespace Edges

// What a popup may do when it would leave the screen.
namespace PopupAdjustment {
Q_NAMESPACE
enum Enum {
    None = 0,
    SlideX = 1,
    SlideY = 2,
    Slide = SlideX | SlideY,
    FlipX = 4,
    FlipY = 8,
    Flip = FlipX | FlipY,
    ResizeX = 16,
    ResizeY = 32,
    Resize = ResizeX | ResizeY,
    All = Slide | Flip | Resize,
};
Q_ENUM_NS(Enum)
} // namespace PopupAdjustment

// Whether a panel reserves room on the screen. Nothing does on Windows;
// it's here so the QML that sets it still reads.
namespace ExclusionMode {
Q_NAMESPACE
enum Enum { Normal = 0, Ignore = 1, Auto = 2 };
Q_ENUM_NS(Enum)
} // namespace ExclusionMode
