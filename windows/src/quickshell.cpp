#include "quickshell.h"

#include <QCursor>
#include <QGuiApplication>
#include <QScreen>

#include <cmath>

ShellScreen::ShellScreen(QScreen* screen, QObject* parent)
    : QObject(parent)
    , m_screen(screen) {
    connect(screen, &QScreen::availableGeometryChanged, this, &ShellScreen::geometryChanged);
    connect(screen, &QScreen::geometryChanged, this, &ShellScreen::geometryChanged);
    connect(screen, &QScreen::physicalDotsPerInchChanged, this, &ShellScreen::geometryChanged);
}

QRect ShellScreen::geometry() const {
    return m_screen->availableGeometry();
}

QString ShellScreen::name() const {
    // Windows calls them \\.\DISPLAY1; the prefix only gets in the way of
    // writing the name in a JSON file.
    QString name = m_screen->name();
    if (name.startsWith(QLatin1String("\\\\.\\")))
        name = name.mid(4);
    return name;
}

QString ShellScreen::model() const {
    return m_screen->model();
}

qreal ShellScreen::devicePixelRatio() const {
    return m_screen->devicePixelRatio();
}

static QuickshellGlobal* globalInstance = nullptr;

QuickshellGlobal::QuickshellGlobal(QObject* parent)
    : QObject(parent) {
    globalInstance = this;
    for (QScreen* screen : QGuiApplication::screens())
        addScreen(screen);
    connect(qApp, &QGuiApplication::screenAdded, this, [this](QScreen* screen) {
        addScreen(screen);
        Q_EMIT screensChanged();
    });
    connect(qApp, &QGuiApplication::screenRemoved, this, [this](QScreen* screen) {
        removeScreen(screen);
        Q_EMIT screensChanged();
    });
}

QuickshellGlobal* QuickshellGlobal::instance() {
    return globalInstance;
}

void QuickshellGlobal::addScreen(QScreen* screen) {
    m_screens.append(new ShellScreen(screen, this));
}

void QuickshellGlobal::removeScreen(QScreen* screen) {
    for (qsizetype i = 0; i < m_screens.size(); i++) {
        if (m_screens[i]->screen() == screen) {
            // Later: a window may still hold it until it moves elsewhere.
            m_screens.takeAt(i)->deleteLater();
            return;
        }
    }
}

QVariantList QuickshellGlobal::screens() const {
    QVariantList list;
    for (ShellScreen* screen : m_screens)
        list.append(QVariant::fromValue(static_cast<QObject*>(screen)));
    return list;
}

ShellScreen* QuickshellGlobal::screenFor(QScreen* screen) const {
    for (ShellScreen* s : m_screens) {
        if (s->screen() == screen)
            return s;
    }
    return m_screens.isEmpty() ? nullptr : m_screens.first();
}

ShellScreen* QuickshellGlobal::screenAtCursor() const {
    QScreen* screen = QGuiApplication::screenAt(QCursor::pos());
    return screenFor(screen ? screen : QGuiApplication::primaryScreen());
}

QVariant QuickshellGlobal::env(const QString& name) const {
    const QByteArray key = name.toLocal8Bit();
    if (!qEnvironmentVariableIsSet(key.constData()))
        return QVariant();
    return qEnvironmentVariable(key.constData());
}

Region::Region(QObject* parent)
    : QObject(parent) {}

void Region::setShape(int shape) {
    if (shape == m_shape)
        return;
    m_shape = shape;
    Q_EMIT changed();
}

void Region::setIntersection(int intersection) {
    if (intersection == m_intersection)
        return;
    m_intersection = intersection;
    Q_EMIT changed();
}

void Region::setX(qreal x) {
    if (x == m_rect.x())
        return;
    m_rect.moveLeft(x);
    Q_EMIT changed();
}

void Region::setY(qreal y) {
    if (y == m_rect.y())
        return;
    m_rect.moveTop(y);
    Q_EMIT changed();
}

void Region::setWidth(qreal width) {
    if (width == m_rect.width())
        return;
    m_rect.setWidth(width);
    Q_EMIT changed();
}

void Region::setHeight(qreal height) {
    if (height == m_rect.height())
        return;
    m_rect.setHeight(height);
    Q_EMIT changed();
}

QQmlListProperty<Region> Region::regions() {
    return QQmlListProperty<Region>(this, nullptr, &Region::appendRegion, &Region::regionCount,
                                    &Region::regionAt, &Region::clearRegions);
}

void Region::appendRegion(QQmlListProperty<Region>* list, Region* region) {
    auto* self = static_cast<Region*>(list->object);
    if (!region)
        return;
    self->m_regions.append(region);
    connect(region, &Region::changed, self, &Region::changed);
    connect(region, &QObject::destroyed, self, [self, region] {
        self->m_regions.removeAll(region);
        Q_EMIT self->changed();
    });
    Q_EMIT self->changed();
}

qsizetype Region::regionCount(QQmlListProperty<Region>* list) {
    return static_cast<Region*>(list->object)->m_regions.size();
}

Region* Region::regionAt(QQmlListProperty<Region>* list, qsizetype index) {
    return static_cast<Region*>(list->object)->m_regions.value(index);
}

void Region::clearRegions(QQmlListProperty<Region>* list) {
    auto* self = static_cast<Region*>(list->object);
    for (Region* region : std::as_const(self->m_regions))
        disconnect(region, nullptr, self, nullptr);
    self->m_regions.clear();
    Q_EMIT self->changed();
}

bool Region::ownContains(const QPointF& point) const {
    if (m_rect.width() <= 0 || m_rect.height() <= 0)
        return false;
    if (m_shape == RegionShape::Ellipse) {
        const qreal rx = m_rect.width() / 2;
        const qreal ry = m_rect.height() / 2;
        const qreal dx = (point.x() - (m_rect.x() + rx)) / rx;
        const qreal dy = (point.y() - (m_rect.y() + ry)) / ry;
        return dx * dx + dy * dy <= 1;
    }
    return m_rect.contains(point);
}

bool Region::contains(const QPointF& point) const {
    bool inside = ownContains(point);
    for (const Region* child : m_regions) {
        const bool there = child->contains(point);
        switch (child->intersection()) {
        case Intersection::Subtract: inside = inside && !there; break;
        case Intersection::Intersect: inside = inside && there; break;
        case Intersection::Xor: inside = inside != there; break;
        default: inside = inside || there; break;
        }
    }
    return inside;
}

bool Region::isEmpty() const {
    if (m_rect.width() > 0 && m_rect.height() > 0)
        return false;
    for (const Region* child : m_regions) {
        if (child->intersection() == Intersection::Combine && !child->isEmpty())
            return false;
    }
    return true;
}
