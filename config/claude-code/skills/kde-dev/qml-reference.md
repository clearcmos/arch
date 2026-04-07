# KDE QML Reference

Detailed QML patterns and best practices for KDE/Plasma development.

## Qt 6 QML Fundamentals

### Property Bindings

```qml
Item {
    id: root

    // Simple binding
    width: parent.width
    height: parent.height / 2

    // Conditional binding
    visible: model.count > 0

    // Binding with multiple dependencies
    opacity: enabled && visible ? 1.0 : 0.5

    // Break binding with explicit assignment (avoid when possible)
    Component.onCompleted: {
        // width = 100  // This breaks the binding!
    }
}
```

### Required Properties (Qt 6)

```qml
// Define required properties in delegates
Item {
    id: delegate

    required property int index
    required property string name
    required property var model

    Text {
        text: delegate.name
    }
}
```

### Signals and Handlers

```qml
Item {
    id: root

    // Custom signal
    signal clicked(point position)
    signal dataReady(var data)

    // Emit signal
    MouseArea {
        onClicked: (mouse) => root.clicked(Qt.point(mouse.x, mouse.y))
    }

    // Connect to signal
    Connections {
        target: someObject
        function onDataReady(data) {
            console.log("Received:", data)
        }
    }
}
```

### Component and Loader

```qml
// Inline component definition
Component {
    id: myComponent

    Rectangle {
        required property string label
        color: "blue"
        Text { text: parent.label }
    }
}

// Dynamic loading
Loader {
    id: loader
    active: needsLoading
    asynchronous: true
    source: "HeavyComponent.qml"

    onLoaded: {
        item.initialize()
    }
}

// Create from component
Button {
    onClicked: {
        let obj = myComponent.createObject(parent, { label: "Hello" })
    }
}
```

## Plasma-Specific Components

### PlasmoidItem

```qml
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // Switch between compact and full at this size
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    // Use default representations or override
    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    // Prefer status area (system tray)
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    // Hide when empty
    hideOnWindowDeactivate: true

    // Background hints
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground
}
```

### PlasmaCore.Types

```qml
import org.kde.plasma.core as PlasmaCore

// Status types
PlasmaCore.Types.UnknownStatus
PlasmaCore.Types.PassiveStatus      // Hidden when not needed
PlasmaCore.Types.ActiveStatus       // Normal visibility
PlasmaCore.Types.NeedsAttentionStatus  // Highlighted

// Background hints
PlasmaCore.Types.NoBackground
PlasmaCore.Types.DefaultBackground
PlasmaCore.Types.TranslucentBackground
PlasmaCore.Types.ShadowBackground

// Form factors
PlasmaCore.Types.Planar         // Desktop
PlasmaCore.Types.Horizontal     // Horizontal panel
PlasmaCore.Types.Vertical       // Vertical panel
PlasmaCore.Types.MediaCenter
PlasmaCore.Types.Application
```

### PlasmaComponents

```qml
import org.kde.plasma.components as PlasmaComponents

// Button
PlasmaComponents.Button {
    text: i18n("Click Me")
    icon.name: "go-next"
    onClicked: doSomething()
}

// ToolButton (for toolbars)
PlasmaComponents.ToolButton {
    icon.name: "configure"
    onClicked: Plasmoid.internalAction("configure").trigger()
}

// Label
PlasmaComponents.Label {
    text: "Status text"
    elide: Text.ElideRight
}

// TextField
PlasmaComponents.TextField {
    placeholderText: i18n("Search...")
    onAccepted: search(text)
}

// CheckBox, RadioButton, Switch
PlasmaComponents.CheckBox {
    text: i18n("Enable feature")
    checked: Plasmoid.configuration.enabled
    onCheckedChanged: Plasmoid.configuration.enabled = checked
}

// ComboBox
PlasmaComponents.ComboBox {
    model: ["Option 1", "Option 2", "Option 3"]
    onCurrentIndexChanged: console.log(currentText)
}

// Slider
PlasmaComponents.Slider {
    from: 0
    to: 100
    value: 50
    stepSize: 1
}

// BusyIndicator
PlasmaComponents.BusyIndicator {
    running: isLoading
}

// TabBar
PlasmaComponents.TabBar {
    PlasmaComponents.TabButton { text: "Tab 1" }
    PlasmaComponents.TabButton { text: "Tab 2" }
}
```

### PlasmaExtras

```qml
import org.kde.plasma.extras as PlasmaExtras

// Expandable list item
PlasmaExtras.ExpandableListItem {
    title: "Item Title"
    subtitle: "Subtitle"
    icon: "document-open"
    isDefault: true

    customExpandedViewContent: ColumnLayout {
        PlasmaComponents.Label { text: "Expanded content" }
    }
}

// Heading
PlasmaExtras.Heading {
    level: 2
    text: "Section Title"
}

// Paragraph (auto-wrapping text)
PlasmaExtras.Paragraph {
    text: "Long text that will wrap automatically..."
}

// Representation (for popups)
PlasmaExtras.Representation {
    header: PlasmaExtras.PlasmoidHeading {
        PlasmaComponents.Label { text: "Header" }
    }

    contentItem: ListView {
        model: myModel
    }
}
```

## KSvg for Theming

```qml
import org.kde.ksvg as KSvg

// Frame using Plasma theme
KSvg.FrameSvgItem {
    imagePath: "widgets/background"
    enabledBorders: KSvg.FrameSvg.TopBorder | KSvg.FrameSvg.BottomBorder
}

// Icon from theme
KSvg.SvgItem {
    svg: KSvg.Svg {
        imagePath: "widgets/arrows"
    }
    elementId: "up-arrow"
}

// Frame SVG border sizes
KSvg.FrameSvgItem {
    id: frame
    imagePath: "widgets/viewitem"
    prefix: "hover"

    // Access margins
    Component.onCompleted: {
        console.log("Top margin:", frame.margins.top)
        console.log("Left margin:", frame.margins.left)
    }
}
```

## Models and Views

### ListView with Plasma Styling

```qml
ListView {
    id: listView

    model: myModel
    currentIndex: -1

    highlight: PlasmaExtras.Highlight {}
    highlightMoveDuration: Kirigami.Units.shortDuration

    delegate: PlasmaExtras.ListItem {
        required property int index
        required property string name
        required property string icon

        contentItem: RowLayout {
            Kirigami.Icon {
                source: icon
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            PlasmaComponents.Label {
                text: name
                Layout.fillWidth: true
            }
        }

        onClicked: listView.currentIndex = index
    }

    // Section headers
    section.property: "category"
    section.delegate: Kirigami.ListSectionHeader {
        required property string section
        text: section
    }
}
```

### Repeater with Positioning

```qml
Flow {
    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: tagModel

        delegate: Kirigami.Chip {
            required property string name
            text: name
            onRemoved: tagModel.removeTag(name)
        }
    }
}
```

## Layout Patterns

### ColumnLayout and RowLayout

```qml
ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    // Fill available width
    PlasmaComponents.Label {
        text: "Full width"
        Layout.fillWidth: true
    }

    // Fixed size
    Rectangle {
        Layout.preferredWidth: 100
        Layout.preferredHeight: 50
    }

    // Stretch to fill
    Item {
        Layout.fillHeight: true
    }

    // Alignment
    PlasmaComponents.Button {
        text: "Centered"
        Layout.alignment: Qt.AlignHCenter
    }
}
```

### GridLayout

```qml
GridLayout {
    columns: 3
    rowSpacing: Kirigami.Units.smallSpacing
    columnSpacing: Kirigami.Units.smallSpacing

    // Span multiple columns
    PlasmaComponents.Label {
        text: "Header"
        Layout.columnSpan: 3
        Layout.fillWidth: true
    }

    PlasmaComponents.Label { text: "Label:" }
    PlasmaComponents.TextField {
        Layout.columnSpan: 2
        Layout.fillWidth: true
    }
}
```

### Kirigami.FormLayout

```qml
Kirigami.FormLayout {
    PlasmaComponents.TextField {
        Kirigami.FormData.label: i18n("Name:")
    }

    PlasmaComponents.ComboBox {
        Kirigami.FormData.label: i18n("Type:")
        model: ["A", "B", "C"]
    }

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Advanced")
    }

    PlasmaComponents.CheckBox {
        Kirigami.FormData.label: i18n("Enable:")
        text: i18n("Advanced mode")
    }
}
```

## Animations

### PropertyAnimation

```qml
Rectangle {
    id: rect

    PropertyAnimation on opacity {
        from: 0
        to: 1
        duration: Kirigami.Units.longDuration
    }

    // Behavior-based animation
    Behavior on x {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InOutQuad
        }
    }
}
```

### SequentialAnimation

```qml
SequentialAnimation {
    id: fadeInOut

    NumberAnimation {
        target: rect
        property: "opacity"
        to: 1
        duration: 200
    }
    PauseAnimation { duration: 1000 }
    NumberAnimation {
        target: rect
        property: "opacity"
        to: 0
        duration: 200
    }
}
```

### States and Transitions

```qml
Item {
    id: root

    states: [
        State {
            name: "expanded"
            PropertyChanges {
                root.height: 200
                expandButton.rotation: 180
            }
        }
    ]

    transitions: Transition {
        NumberAnimation {
            properties: "height,rotation"
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InOutQuad
        }
    }
}
```

## KConfig XT Integration

### kcfg File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.kde.org/standards/kcfg/1.0
      http://www.kde.org/standards/kcfg/1.0/kcfg.xsd">
  <kcfgfile name="myapprc"/>
  <group name="General">
    <entry name="ShowLabel" type="Bool">
      <default>true</default>
    </entry>
    <entry name="LabelText" type="String">
      <default>Hello</default>
    </entry>
    <entry name="UpdateInterval" type="Int">
      <default>60</default>
      <min>10</min>
      <max>3600</max>
    </entry>
  </group>
</kcfg>
```

### config.qml for Plasmoid

```qml
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    // Property aliases auto-bind to Plasmoid.configuration
    property alias cfg_ShowLabel: showLabelCheck.checked
    property alias cfg_LabelText: labelField.text
    property alias cfg_UpdateInterval: intervalSpinBox.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLabelCheck
            Kirigami.FormData.label: i18n("Show label:")
        }

        QQC2.TextField {
            id: labelField
            Kirigami.FormData.label: i18n("Label text:")
            enabled: showLabelCheck.checked
        }

        QQC2.SpinBox {
            id: intervalSpinBox
            Kirigami.FormData.label: i18n("Update interval (seconds):")
            from: 10
            to: 3600
        }
    }
}
```

## Drag and Drop

### DropArea

```qml
DropArea {
    id: dropArea

    onEntered: (drag) => {
        if (drag.hasUrls) {
            drag.accepted = true
        }
    }

    onDropped: (drop) => {
        for (let url of drop.urls) {
            console.log("Dropped:", url)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: dropArea.containsDrag ? "lightblue" : "transparent"
    }
}
```

### Draggable Item

```qml
Item {
    id: draggable

    Drag.active: dragArea.drag.active
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: {
        "text/uri-list": fileUrl
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: draggable
    }
}
```

## Performance Best Practices

### Lazy Loading

```qml
// Only load when needed
Loader {
    active: tabBar.currentIndex === 2
    source: "HeavyTab.qml"
}

// Async loading for large components
Loader {
    asynchronous: true
    source: visible ? "BigComponent.qml" : ""
}
```

### Avoid JavaScript in Bindings

```qml
// Bad - complex JS in binding
width: {
    let w = parent.width
    if (condition) {
        w = w * 0.5
    }
    return Math.max(w, 100)
}

// Better - use ternary or simple expressions
width: condition ? parent.width * 0.5 : parent.width
```

### Use Shader Effects Sparingly

```qml
// Only apply effects when needed
layer.enabled: showShadow
layer.effect: DropShadow {
    radius: 8
    samples: 17
}
```

### Delegate Optimization

```qml
ListView {
    // Enable recycling
    reuseItems: true

    // Cache delegates
    cacheBuffer: height * 2

    delegate: ItemDelegate {
        // Avoid nested Loaders in delegates
        // Use conditional visibility instead
        Image {
            visible: hasImage
            source: visible ? imageUrl : ""
        }
    }
}
```

## Debugging

### Console Output

```qml
Component.onCompleted: {
    console.log("Object created:", this)
    console.debug("Debug info")
    console.warn("Warning message")
    console.error("Error occurred")
}
```

### QML Profiler

```bash
# Run with QML profiler
QT_QUICK_CONTROLS_STYLE=Desktop \
QML_IMPORT_TRACE=1 \
plasmashell --qmljsdebugger=port:3768,block
```

### Common Issues

```qml
// Check for undefined
if (typeof myProperty !== "undefined") {
    // Safe to use
}

// Check binding loops
onWidthChanged: {
    // Don't set properties that affect width here!
}

// Null checks for model roles
text: model.name ?? ""
```
