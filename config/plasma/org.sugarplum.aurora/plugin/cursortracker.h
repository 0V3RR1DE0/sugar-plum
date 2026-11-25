#pragma once

#include <QObject>
#include <QPointF>
#include <QQmlParserStatus>
#include <QtQml/qqmlregistration.h>

class QQuickItem;
class QQuickWindow;

class CursorTracker : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_ELEMENT
    Q_PROPERTY(QPointF position READ position NOTIFY positionChanged)
    Q_PROPERTY(bool tracking READ tracking WRITE setTracking NOTIFY trackingChanged)

public:
    explicit CursorTracker(QObject *parent = nullptr);

    QPointF position() const { return m_position; }
    bool tracking() const { return m_tracking; }
    void setTracking(bool tracking);

    void classBegin() override {}
    void componentComplete() override;

signals:
    void positionChanged();
    void trackingChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void attachWindow(QQuickWindow *window);
    void updatePosition(const QPointF &scenePos);

    QPointF m_position{0.5, 0.5};
    bool m_tracking = true;
    QQuickItem *m_item = nullptr;
    QQuickWindow *m_window = nullptr;
};
