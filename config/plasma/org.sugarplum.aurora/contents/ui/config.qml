import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    property string cfg_Style: "dusk"
    property real cfg_Speed: 1.0
    property real cfg_Intensity: 1.0
    property bool cfg_Stars: true
    property bool cfg_PauseOnCover: true

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.ComboBox {
            id: styleBox
            Kirigami.FormData.label: "Style:"
            textRole: "text"
            valueRole: "value"
            model: [
                { text: "Quiet Dusk", value: "dusk" },
                { text: "Silk Ribbons", value: "silk" }
            ]
            currentIndex: {
                for (let i = 0; i < model.length; ++i) {
                    if (model[i].value === root.cfg_Style) {
                        return i;
                    }
                }
                return 0;
            }
            onActivated: root.cfg_Style = model[currentIndex].value
        }

        QQC2.Slider {
            Kirigami.FormData.label: "Speed:"
            from: 0.2
            to: 2.0
            stepSize: 0.1
            value: root.cfg_Speed
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            onMoved: root.cfg_Speed = value
        }

        QQC2.Slider {
            Kirigami.FormData.label: "Glow intensity:"
            from: 0.4
            to: 1.6
            stepSize: 0.05
            value: root.cfg_Intensity
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            onMoved: root.cfg_Intensity = value
        }

        QQC2.Switch {
            Kirigami.FormData.label: "Stars:"
            checked: root.cfg_Stars
            onToggled: root.cfg_Stars = checked
        }

        QQC2.Switch {
            Kirigami.FormData.label: "Pause when covered:"
            checked: root.cfg_PauseOnCover
            onToggled: root.cfg_PauseOnCover = checked
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: "Quiet Dusk is the calm two-glow look. Silk Ribbons is the flowing aurora look."
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }
}
