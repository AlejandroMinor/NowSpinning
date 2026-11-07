#include "panelwindow.h"

#include <QCursor>
#include <QGuiApplication>
#include <QQmlListReference>
#include <QScreen>

#include <cmath>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {

#ifdef Q_OS_WIN
// Clicks go through a window Windows draws with per-window transparency
// (WS_EX_LAYERED) once it's also WS_EX_TRANSPARENT. Qt makes a frameless
// translucent window layered already, so only the second bit changes, a
// cheap call that's safe to make on every poll. False when the window isn't
// layered, for Qt to make it so.
bool setClickThroughNative(QWindow* window, bool through) {
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    const LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    if (!(style & WS_EX_LAYERED))
        return false;
    const LONG_PTR next = through ? (style | WS_EX_TRANSPARENT) : (style & ~LONG_PTR(WS_EX_TRANSPARENT));
    if (next != style)
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, next);
    return true;
}

// Puts the window above every other one ("overlay", "top") or below them
// ("bottom"), now. Qt only changes the flag: a window already behind the
// others stays there when it becomes always on top, until it's raised.
void setStackingNative(QWindow* window, bool onTop) {
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    SetWindowPos(hwnd, onTop ? HWND_TOPMOST : HWND_BOTTOM, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
}
#endif

// How often the pointer is checked against a window's mask. Fast enough
// that the widget answers the moment the pointer is over it.
constexpr int inputPollMs = 30;

} // namespace

ProxyWindow::ProxyWindow(QObject* parent)
    : QObject(parent)
    , m_window(new QQuickWindow()) {
    m_window->setColor(m_color);
    m_window->setTitle(QStringLiteral("NowSpinning"));

    connect(m_window, &QWindow::xChanged, this, &ProxyWindow::geometryChanged);
    connect(m_window, &QWindow::yChanged, this, &ProxyWindow::geometryChanged);
    connect(m_window, &QWindow::widthChanged, this, [this] {
        Q_EMIT widthChanged();
        Q_EMIT geometryChanged();
    });
    connect(m_window, &QWindow::heightChanged, this, [this] {
        Q_EMIT heightChanged();
        Q_EMIT geometryChanged();
    });

    m_inputPoll.setInterval(inputPollMs);
    connect(&m_inputPoll, &QTimer::timeout, this, &ProxyWindow::updateInput);
}

ProxyWindow::~ProxyWindow() {
    m_inputPoll.stop();
    // What QML made inside it belongs to this object, and would only go
    // after the window, letting go of a window already gone. It goes first.
    while (!children().isEmpty())
        delete children().constFirst();
    delete m_window;
}

void ProxyWindow::componentComplete() {
    m_complete = true;
    if (!m_screen)
        m_pickedScreen = QuickshellGlobal::instance()->screenAtCursor();
    applyFlags();
    applyGeometry();
    applyVisible();
}

void ProxyWindow::setVisible(bool visible) {
    if (visible == m_visible)
        return;
    m_visible = visible;
    applyVisible();
    Q_EMIT visibleChanged();
}

void ProxyWindow::applyVisible() {
    if (!m_complete)
        return;
    if (m_visible) {
        applyGeometry();
        m_window->setVisible(true);
#ifdef Q_OS_WIN
        setStackingNative(m_window, m_layer >= WlrLayer::Top);
#endif
        m_clickThroughKnown = false;
        updateInput();
    } else {
        m_inputPoll.stop();
        m_window->setVisible(false);
    }
}

void ProxyWindow::setColor(const QColor& color) {
    if (color == m_color)
        return;
    m_color = color;
    m_window->setColor(color);
    Q_EMIT colorChanged();
}

void ProxyWindow::setImplicitWidth(qreal width) {
    if (width == m_implicitWidth)
        return;
    m_implicitWidth = width;
    Q_EMIT implicitWidthChanged();
    scheduleGeometry();
}

void ProxyWindow::setImplicitHeight(qreal height) {
    if (height == m_implicitHeight)
        return;
    m_implicitHeight = height;
    Q_EMIT implicitHeightChanged();
    scheduleGeometry();
}

qreal ProxyWindow::width() const {
    return size().width();
}

void ProxyWindow::setWidth(qreal width) {
    m_width = width;
    scheduleGeometry();
}

qreal ProxyWindow::height() const {
    return size().height();
}

void ProxyWindow::setHeight(qreal height) {
    m_height = height;
    scheduleGeometry();
}

QSize ProxyWindow::size() const {
    const qreal w = m_width >= 0 ? m_width : m_implicitWidth;
    const qreal h = m_height >= 0 ? m_height : m_implicitHeight;
    return QSize(std::max(1, int(std::lround(w))), std::max(1, int(std::lround(h))));
}

ShellScreen* ProxyWindow::screen() const {
    if (m_screen)
        return m_screen;
    if (m_pickedScreen)
        return m_pickedScreen;
    return QuickshellGlobal::instance()->screenAtCursor();
}

void ProxyWindow::setScreen(ShellScreen* screen) {
    ShellScreen* before = this->screen();
    if (before)
        disconnect(before, &ShellScreen::geometryChanged, this, nullptr);

    m_screen = screen;
    // With none given, the one under the pointer, picked again each time,
    // the way the compositor places a surface without an output.
    m_pickedScreen = screen ? nullptr : QuickshellGlobal::instance()->screenAtCursor();

    ShellScreen* after = this->screen();
    if (after)
        connect(after, &ShellScreen::geometryChanged, this, &ProxyWindow::scheduleGeometry);
    if (after != before)
        Q_EMIT screenChanged();
    scheduleGeometry();
}

void ProxyWindow::setMask(Region* mask) {
    if (mask == m_mask)
        return;
    if (m_mask)
        disconnect(m_mask, nullptr, this, nullptr);
    m_mask = mask;
    if (m_mask)
        connect(m_mask, &Region::changed, this, &ProxyWindow::updateInput);
    m_clickThroughKnown = false;
    updateInput();
    Q_EMIT maskChanged();
}

QQuickItem* ProxyWindow::contentItem() const {
    return m_window->contentItem();
}

void ProxyWindow::setLayer(int layer) {
    if (layer == m_layer)
        return;
    m_layer = layer;
    applyFlags();
}

void ProxyWindow::setTitle(const QString& title) {
    m_window->setTitle(title);
}

void ProxyWindow::applyFlags() {
    Qt::WindowFlags flags = Qt::FramelessWindowHint | Qt::Tool | Qt::NoDropShadowWindowHint
        | Qt::WindowDoesNotAcceptFocus | extraFlags();
    if (m_layer >= WlrLayer::Top)
        flags |= Qt::WindowStaysOnTopHint;
    else
        flags |= Qt::WindowStaysOnBottomHint;
    if (m_clickThrough && m_clickThroughKnown && !m_nativeClickThrough)
        flags |= Qt::WindowTransparentForInput;

    if (m_window->flags() != flags) {
        m_window->setFlags(flags);
        // Setting the flags again may have reset the native click-through.
        m_clickThroughKnown = false;
        updateInput();
#ifdef Q_OS_WIN
        if (m_window->isVisible())
            setStackingNative(m_window, m_layer >= WlrLayer::Top);
#endif
    }
}

void ProxyWindow::scheduleGeometry() {
    if (!m_complete || m_geometryPending)
        return;
    // Margins and size often change together (a drag sets left, then top):
    // one move for all of them, before the next frame.
    m_geometryPending = true;
    QMetaObject::invokeMethod(this, &ProxyWindow::applyGeometry, Qt::QueuedConnection);
}

void ProxyWindow::applyGeometry() {
    m_geometryPending = false;
    if (!m_complete)
        return;

    ShellScreen* screen = this->screen();
    if (screen && m_window->screen() != screen->screen() && !m_window->isVisible())
        m_window->setScreen(screen->screen());

    const QRect geometry = targetGeometry();
    if (geometry != m_window->geometry())
        m_window->setGeometry(geometry);
    updateInput();
}

void ProxyWindow::updateInput() {
    if (!m_complete || !m_window->isVisible()) {
        m_inputPoll.stop();
        return;
    }

    bool through;
    if (!m_mask) {
        through = false;
        m_inputPoll.stop();
    } else if (m_mask->isEmpty()) {
        through = true;
        m_inputPoll.stop();
    } else {
        if (!m_inputPoll.isActive())
            m_inputPoll.start();
        if (!m_clickThrough && m_clickThroughKnown && QGuiApplication::mouseButtons() != Qt::NoButton) {
            // A drag that started inside keeps the pointer wherever it goes.
            through = false;
        } else {
            const QPointF local = QPointF(QCursor::pos()) - QPointF(m_window->position());
            through = !m_mask->contains(local);
        }
    }
    setClickThrough(through);
}

void ProxyWindow::setClickThrough(bool through) {
#ifdef Q_OS_WIN
    // Checked every time, not only on a change: Qt may set the window's
    // styles again on its own.
    if (setClickThroughNative(m_window, through)) {
        m_nativeClickThrough = true;
        m_clickThrough = through;
        m_clickThroughKnown = true;
        return;
    }
#endif
    if (m_clickThroughKnown && through == m_clickThrough)
        return;
    m_nativeClickThrough = false;
    m_clickThrough = through;
    m_clickThroughKnown = true;
    m_window->setFlag(Qt::WindowTransparentForInput, through);
}

QQmlListProperty<QObject> ProxyWindow::data() {
    return QQmlListProperty<QObject>(this, nullptr, &ProxyWindow::appendData, &ProxyWindow::dataCount,
                                     &ProxyWindow::dataAt, &ProxyWindow::clearData);
}

// What's declared inside the window goes into its content item, items,
// handlers and plain objects alike, as under Quickshell.
void ProxyWindow::appendData(QQmlListProperty<QObject>* list, QObject* object) {
    auto* self = static_cast<ProxyWindow*>(list->object);
    QQmlListReference(self->contentItem(), "data").append(object);
}

qsizetype ProxyWindow::dataCount(QQmlListProperty<QObject>* list) {
    auto* self = static_cast<ProxyWindow*>(list->object);
    return QQmlListReference(self->contentItem(), "data").count();
}

QObject* ProxyWindow::dataAt(QQmlListProperty<QObject>* list, qsizetype index) {
    auto* self = static_cast<ProxyWindow*>(list->object);
    return QQmlListReference(self->contentItem(), "data").at(index);
}

void ProxyWindow::clearData(QQmlListProperty<QObject>* list) {
    auto* self = static_cast<ProxyWindow*>(list->object);
    QQmlListReference(self->contentItem(), "data").clear();
}

PanelWindow::PanelWindow(QObject* parent)
    : ProxyWindow(parent)
    , m_anchors(new Anchors(this))
    , m_margins(new Margins(this)) {
    connect(m_anchors, &Anchors::changed, this, &PanelWindow::scheduleGeometry);
    connect(m_margins, &Margins::changed, this, &PanelWindow::scheduleGeometry);
}

void PanelWindow::setExclusionMode(int mode) {
    if (mode == m_exclusionMode)
        return;
    m_exclusionMode = mode;
    Q_EMIT exclusionModeChanged();
}

void PanelWindow::setExclusiveZone(int zone) {
    if (zone == m_exclusiveZone)
        return;
    m_exclusiveZone = zone;
    Q_EMIT exclusiveZoneChanged();
}

void PanelWindow::setFocusable(bool focusable) {
    if (focusable == m_focusable)
        return;
    m_focusable = focusable;
    Q_EMIT focusableChanged();
}

// Where the compositor would put a layer surface with these anchors and
// margins: against each anchored edge, at its margin from it, and centered
// along an axis with neither edge anchored. Both edges anchored stretch it.
QRect PanelWindow::targetGeometry() const {
    ShellScreen* screen = this->screen();
    const QRect area = screen ? screen->geometry() : QRect(0, 0, 1920, 1080);
    QSize size = this->size();

    int x;
    if (m_anchors->m_left && m_anchors->m_right) {
        x = area.x() + m_margins->m_left;
        size.setWidth(std::max(1, area.width() - m_margins->m_left - m_margins->m_right));
    } else if (m_anchors->m_left) {
        x = area.x() + m_margins->m_left;
    } else if (m_anchors->m_right) {
        x = area.x() + area.width() - size.width() - m_margins->m_right;
    } else {
        x = area.x() + (area.width() - size.width()) / 2;
    }

    int y;
    if (m_anchors->m_top && m_anchors->m_bottom) {
        y = area.y() + m_margins->m_top;
        size.setHeight(std::max(1, area.height() - m_margins->m_top - m_margins->m_bottom));
    } else if (m_anchors->m_top) {
        y = area.y() + m_margins->m_top;
    } else if (m_anchors->m_bottom) {
        y = area.y() + area.height() - size.height() - m_margins->m_bottom;
    } else {
        y = area.y() + (area.height() - size.height()) / 2;
    }

    return QRect(QPoint(x, y), size);
}

PopupAnchor::PopupAnchor(QObject* parent)
    : QObject(parent)
    , m_rect(new AnchorRect(this)) {
    connect(m_rect, &AnchorRect::changed, this, &PopupAnchor::changed);
}

void PopupAnchor::setWindow(QObject* window) {
    if (window == m_window)
        return;
    m_window = window;
    Q_EMIT changed();
}

void PopupAnchor::updateAnchor() {
    Q_EMIT anchoring();
}

PopupWindow::PopupWindow(QObject* parent)
    : ProxyWindow(parent)
    , m_anchor(new PopupAnchor(this)) {
    connect(m_anchor, &PopupAnchor::changed, this, &PopupWindow::followParent);
    connect(m_anchor, &PopupAnchor::anchoring, this, &PopupWindow::scheduleGeometry);
    setTitle(QStringLiteral("NowSpinning settings"));
}

void PopupWindow::componentComplete() {
    followParent();
    ProxyWindow::componentComplete();
}

// Keeps to its parent: its screen, its layer, and wherever it moves.
void PopupWindow::followParent() {
    auto* parent = qobject_cast<ProxyWindow*>(m_anchor->window());
    if (parent != m_parentWindow) {
        if (m_parentWindow)
            disconnect(m_parentWindow, nullptr, this, nullptr);
        m_parentWindow = parent;
        if (parent) {
            connect(parent, &ProxyWindow::geometryChanged, this, &PopupWindow::scheduleGeometry);
            connect(parent, &ProxyWindow::screenChanged, this, [this] { setScreen(m_parentWindow->screen()); });
            window()->setTransientParent(parent->window());
            setScreen(parent->screen());
            setLayer(parent->layer());
        }
    }
    if (parent)
        setLayer(parent->layer());
    scheduleGeometry();
}

// Quickshell's popup placement: the anchor point on the anchor rect's
// `edges`, the popup growing from it toward `gravity`; then, if it would
// leave the screen, flipped to the other side where that fits, and slid
// back inside.
QRect PopupWindow::targetGeometry() const {
    const QSize size = this->size();
    const qreal w = size.width();
    const qreal h = size.height();

    const QPoint origin = m_parentWindow ? m_parentWindow->window()->position() : QPoint();
    const AnchorRect* r = m_anchor->rect();
    const QRectF rect(origin.x() + r->m_x, origin.y() + r->m_y, r->m_width, r->m_height);

    const int edges = m_anchor->m_edges;
    const int gravity = m_anchor->m_gravity;
    const int adjustment = m_anchor->m_adjustment;

    auto anchorX = [&](int e) {
        return (e & Edges::Left) ? rect.left() : (e & Edges::Right) ? rect.right() : rect.center().x();
    };
    auto anchorY = [&](int e) {
        return (e & Edges::Top) ? rect.top() : (e & Edges::Bottom) ? rect.bottom() : rect.center().y();
    };
    auto placeX = [&](int g, qreal ax) {
        return (g & Edges::Left) ? ax - w : (g & Edges::Right) ? ax : ax - w / 2;
    };
    auto placeY = [&](int g, qreal ay) {
        return (g & Edges::Top) ? ay - h : (g & Edges::Bottom) ? ay : ay - h / 2;
    };
    auto swapX = [](int e) {
        const int lr = e & (Edges::Left | Edges::Right);
        if (lr == Edges::Left || lr == Edges::Right)
            e ^= Edges::Left | Edges::Right;
        return e;
    };
    auto swapY = [](int e) {
        const int tb = e & (Edges::Top | Edges::Bottom);
        if (tb == Edges::Top || tb == Edges::Bottom)
            e ^= Edges::Top | Edges::Bottom;
        return e;
    };

    ShellScreen* screen = this->screen();
    const QRect area = screen ? screen->geometry() : QRect(0, 0, 1920, 1080);
    const qreal left = area.x();
    const qreal top = area.y();
    const qreal right = area.x() + area.width();
    const qreal bottom = area.y() + area.height();

    qreal x = placeX(gravity, anchorX(edges));
    qreal y = placeY(gravity, anchorY(edges));

    if (adjustment & PopupAdjustment::FlipX) {
        const bool out = ((gravity & Edges::Left) && x < left) || ((gravity & Edges::Right) && x + w > right);
        if (out) {
            const int g = swapX(gravity);
            const qreal flipped = placeX(g, anchorX(swapX(edges)));
            const bool fits = (g & Edges::Left) ? flipped >= left : flipped + w <= right;
            if (fits)
                x = flipped;
        }
    }
    if (adjustment & PopupAdjustment::FlipY) {
        const bool out = ((gravity & Edges::Top) && y < top) || ((gravity & Edges::Bottom) && y + h > bottom);
        if (out) {
            const int g = swapY(gravity);
            const qreal flipped = placeY(g, anchorY(swapY(edges)));
            const bool fits = (g & Edges::Top) ? flipped >= top : flipped + h <= bottom;
            if (fits)
                y = flipped;
        }
    }
    if (adjustment & PopupAdjustment::SlideX)
        x = std::max(left, std::min(x, right - w));
    if (adjustment & PopupAdjustment::SlideY)
        y = std::max(top, std::min(y, bottom - h));

    return QRect(QPoint(int(std::lround(x)), int(std::lround(y))), size);
}

WlrLayershell::WlrLayershell(QObject* parent)
    : QObject(parent) {}

WlrLayershell* WlrLayershell::qmlAttachedProperties(QObject* object) {
    auto* attached = new WlrLayershell(object);
    attached->m_window = qobject_cast<ProxyWindow*>(object);
    if (attached->m_window)
        attached->m_window->setLayer(attached->m_layer);
    return attached;
}

void WlrLayershell::setLayer(int layer) {
    if (layer == m_layer)
        return;
    m_layer = layer;
    if (m_window)
        m_window->setLayer(layer);
    Q_EMIT layerChanged();
}

void WlrLayershell::setNs(const QString& ns) {
    if (ns == m_ns)
        return;
    m_ns = ns;
    if (m_window)
        m_window->setTitle(ns);
    Q_EMIT nsChanged();
}
