import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Balthasar-style glass: the backdrop behind the panel, blurred and tinted
// dark, inside a rounded "sunlit" edge (bright on top, accent-tinted at the
// bottom when active, dim when not). Children go on top.
Item {
    id: g
    property real radius: Theme.px(18)
    property bool active: false
    property bool elevated: false   // heavier, darker shadow (pill, selected tile, dialogs)
    property color fill: Theme.glass
    property Item backdrop: Theme.backdrop
    // Bind to anything that moves the panel without changing its own x/y
    // (list scrolling, a parent's scale), so the blurred patch follows.
    property var track: 0
    default property alias content: inner.data

    readonly property real pad: Theme.px(40)   // extra blur source so edges don't darken
    readonly property rect area: {
        track; x; y; width; height;   // dependencies
        if (!backdrop || width <= 0) return Qt.rect(0, 0, 1, 1);
        const p = mapToItem(backdrop, -pad, -pad);
        const q = mapToItem(backdrop, width + pad, height + pad);
        return Qt.rect(p.x, p.y, q.x - p.x, q.y - p.y);
    }

    // drop shadow, Balthasar-style: light from above, so it falls slightly
    // below. The panel's own area is masked out so the shadow doesn't
    // darken the glass from underneath.
    // The shadow is drawn into its own padded layer, then the panel's shape
    // is cut out of that layer with a mask of exactly the same size.
    readonly property real shadowPad: Theme.px(64)
    Rectangle {
        id: shadowShape
        anchors.fill: parent
        radius: g.radius
        color: "black"
        visible: false
        layer.enabled: true
    }
    Item {
        id: shadowLayer
        x: -g.shadowPad; y: -g.shadowPad
        width: g.width + 2 * g.shadowPad; height: g.height + 2 * g.shadowPad
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: shadowCut
            maskSpreadAtMin: 0.3   // soft edge, no jaggies on the rounded corners
        }
        MultiEffect {
            x: g.shadowPad; y: g.shadowPad
            width: g.width; height: g.height
            source: shadowShape
            shadowEnabled: true
            shadowColor: g.elevated ? Theme.shadowHeavy : Theme.shadowSubtle
            shadowBlur: 1.0
            blurMax: g.elevated ? Theme.px(40) : Theme.px(24)
            shadowVerticalOffset: g.elevated ? Theme.px(8) : Theme.px(4)
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
            Behavior on shadowColor { ColorAnimation { duration: Theme.anim } }
        }
    }
    Item {
        id: shadowCut
        x: -g.shadowPad; y: -g.shadowPad
        width: shadowLayer.width; height: shadowLayer.height
        visible: false
        layer.enabled: true
        Rectangle {
            x: g.shadowPad; y: g.shadowPad
            width: g.width; height: g.height
            radius: g.radius
            color: "white"
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: g.radius
        color: "transparent"

        ShaderEffectSource {
            id: behind
            visible: false
            sourceItem: g.backdrop
            sourceRect: g.area
            live: true
        }
        MultiEffect {
            visible: g.backdrop !== null
            x: -g.pad; y: -g.pad
            width: g.width + 2 * g.pad; height: g.height + 2 * g.pad
            source: behind
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
        }
        Rectangle {   // dark tint
            anchors.fill: parent
            color: g.fill
            Behavior on color { ColorAnimation { duration: Theme.anim } }
        }
    }

    // children (below the edge, so full-bleed content like card images
    // still gets the sunlit border on top)
    Item { id: inner; anchors.fill: parent }

    // sunlit edge: a vertical gradient, masked to a ring
    Rectangle {
        id: edgeGradient
        anchors.fill: parent
        radius: g.radius
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: g.active ? Theme.edgeActiveTop : Theme.edgeInactiveTop }
            GradientStop { position: 1.0; color: g.active ? Theme.edgeActiveBottom : Theme.edgeInactiveBottom }
        }
    }
    Rectangle {
        id: ring
        anchors.fill: parent
        radius: g.radius
        color: "transparent"
        border.width: g.active ? Theme.px(2) : Math.max(1, Theme.px(1))
        border.color: "white"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: edgeGradient
        maskEnabled: true
        maskSource: ring
    }
}
