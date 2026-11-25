#include "cursortracker.h"

#include <QEvent>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTimer>

CursorTracker::CursorTracker(QObject *parent)
    : QObject(parent)
{
}

void CursorTracker::setTracking(bool tracking)
{
    if (m_tracking == tracking) {
        return;
    }
    m_tracking = tracking;
    Q_EMIT trackingChanged();
}

void CursorTracker::componentComplete()
{
    m_item = qobject_cast<QQuickItem *>(parent());
    if (!m_item) {
        return;
    }

    attachWindow(m_item->window());
    connect(m_item, &QQuickItem::windowChanged, this, [this](QQuickWindow *window) {
        attachWindow(window);
    });

    // The wallpaper window may not exist yet when the item completes.
    QTimer::singleShot(0, this, [this] {
        if (!m_window && m_item) {
            attachWindow(m_item->window());
        }
    });
}

void CursorTracker::attachWindow(QQuickWindow *window)
{
    if (m_window == window) {
        return;
    }
    if (m_window) {
        m_window->removeEventFilter(this);
    }
    m_window = window;
    if (m_window) {
        m_window->installEventFilter(this);
    }
}

void CursorTracker::updatePosition(const QPointF &scenePos)
{
    if (!m_item || m_item->width() <= 0 || m_item->height() <= 0) {
        return;
    }

    const QPointF local = m_item->mapFromScene(scenePos);
    const QPointF normalized(local.x() / m_item->width(), local.y() / m_item->height());
    if (normalized != m_position) {
        m_position = normalized;
        Q_EMIT positionChanged();
    }
}

bool CursorTracker::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)
    if (!m_tracking || !m_item) {
        return false;
    }

    // The desktop containment receives hover moves, not mouse moves, unless a
    // button is held. Handle both so the wallpaper follows the pointer.
    if (event->type() == QEvent::MouseMove) {
        updatePosition(static_cast<QMouseEvent *>(event)->position());
    } else if (event->type() == QEvent::HoverMove || event->type() == QEvent::HoverEnter) {
        updatePosition(static_cast<QHoverEvent *>(event)->position());
    }
    return false;
}
