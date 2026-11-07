// Quickshell.Widgets' ClippingRectangle: a rectangle whose rounded corners
// cut off what's inside it, inside its border. The content is drawn into
// a layer and masked to the rounded shape; with no rounding, a plain clip.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property alias color: background.color
    property real radius: 0
    property alias border: frame.border
    // Inside the border, or under it.
    property bool contentInsideBorder: true
    property alias antialiasing: background.antialiasing
    readonly property alias contentItem: content
    default property alias contentData: content.data

    readonly property real inset: contentInsideBorder ? frame.border.width : 0
    readonly property real innerRadius: Math.max(0, radius - inset)

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.inset
        clip: root.innerRadius <= 0
        layer.enabled: root.innerRadius > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        id: shape
        width: content.width
        height: content.height
        radius: root.innerRadius
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 0
        antialiasing: true
        visible: border.width > 0
    }
}
