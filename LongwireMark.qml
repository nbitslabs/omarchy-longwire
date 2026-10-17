import QtQuick
import QtQuick.Shapes

// The longwire mark drawn natively so it takes the theme's colors: a wire
// run between two rings, with the packet dot riding its middle. The dot is
// the widget's status light — its color and pulse come from the caller.
Item {
  id: root

  property real size: 16
  property color color: "white"
  property color packetColor: color
  property real packetOpacity: 1.0
  property bool pulse: false

  implicitWidth: size
  implicitHeight: size

  // Artwork is authored on a 96-unit square; the glyph fills ~80% of it.
  readonly property real k: size / 96

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.color
      strokeWidth: 7.5 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: 21 * root.k; startY: 68 * root.k
      PathLine { x: 36 * root.k; y: 68 * root.k }
      PathCubic {
        x: 60 * root.k; y: 28 * root.k
        control1X: 50 * root.k; control1Y: 68 * root.k
        control2X: 46 * root.k; control2Y: 28 * root.k
      }
      PathLine { x: 75 * root.k; y: 28 * root.k }
    }

    ShapePath {
      strokeColor: root.color
      strokeWidth: 5.5 * root.k
      fillColor: "transparent"
      PathAngleArc { centerX: 14 * root.k; centerY: 68 * root.k; radiusX: 7.5 * root.k; radiusY: 7.5 * root.k; startAngle: 0; sweepAngle: 360 }
    }

    ShapePath {
      strokeColor: root.color
      strokeWidth: 5.5 * root.k
      fillColor: "transparent"
      PathAngleArc { centerX: 82 * root.k; centerY: 28 * root.k; radiusX: 7.5 * root.k; radiusY: 7.5 * root.k; startAngle: 0; sweepAngle: 360 }
    }
  }

  Rectangle {
    id: packet
    // Larger than the brand's packet so it still reads as a status light
    // at bar size.
    width: 26 * root.k
    height: width
    radius: width / 2
    x: 48 * root.k - width / 2
    y: 48 * root.k - height / 2
    color: root.packetColor
    opacity: root.packetOpacity

    SequentialAnimation on opacity {
      running: root.pulse
      loops: Animation.Infinite
      alwaysRunToEnd: true
      NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
      NumberAnimation { to: root.packetOpacity; duration: 800; easing.type: Easing.InOutQuad }
    }
  }
}
