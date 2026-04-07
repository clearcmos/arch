---
name: kde-dev
description: "KDE/Qt development reference - CMake, QML, KDE Frameworks, Plasma, Kirigami patterns"
user-invocable: true
disable-model-invocation: true
---

# KDE Development Reference

Reference for KDE Plasma and Qt/QML development including CMake patterns, KDE Frameworks, Kirigami, and Plasma widget development.

## Development Setup

### Using kdesrc-build (Recommended)

```bash
# Install kdesrc-build
mkdir -p ~/kde/src
cd ~/kde/src
git clone https://invent.kde.org/sdk/kdesrc-build.git
cd kdesrc-build
./kdesrc-build --initial-setup

# Build a project
kdesrc-build dolphin

# Build with dependencies
kdesrc-build --include-dependencies dolphin

# Run built application
source ~/kde/build/dolphin/prefix.sh
dolphin
```

### Manual Build

```bash
# Standard CMake workflow
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=Debug \
      -DBUILD_TESTING=ON \
      ..
make -j$(nproc)
sudo make install

# With Ninja (faster)
cmake -GNinja -DCMAKE_BUILD_TYPE=Debug ..
ninja
```

### NixOS Development

```bash
# Enter development shell with Qt and KDE deps
nix develop

# Or with specific packages
nix-shell -p qt6.full kdePackages.extra-cmake-modules
```

## Project Structure

### Standard KDE Application

```
my-app/
├── CMakeLists.txt           # Root CMake configuration
├── CMakePresets.json        # CMake presets (optional)
├── src/
│   ├── CMakeLists.txt       # Source CMake
│   ├── main.cpp             # Application entry point
│   ├── mainwindow.cpp       # Main window implementation
│   ├── mainwindow.h
│   └── resources.qrc        # Qt resource file
├── data/
│   ├── org.kde.myapp.desktop
│   ├── org.kde.myapp.appdata.xml
│   └── icons/
├── po/                      # Translations
└── doc/                     # Documentation
```

### Plasma Widget/Applet

```
my-applet/
├── CMakeLists.txt
├── package/
│   ├── metadata.json        # Applet metadata
│   └── contents/
│       ├── ui/
│       │   ├── main.qml     # Main UI
│       │   ├── CompactRepresentation.qml
│       │   └── FullRepresentation.qml
│       └── config/
│           └── config.qml   # Settings UI
└── plugin/                  # Optional C++ backend
    ├── CMakeLists.txt
    └── myplugin.cpp
```

## CMake Patterns

### Basic KDE Application

```cmake
cmake_minimum_required(VERSION 3.16)
project(myapp VERSION 1.0.0)

set(QT_MIN_VERSION "6.4.0")
set(KF6_MIN_VERSION "6.0.0")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ECM setup
find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMSetupVersion)
include(FeatureSummary)

# Qt
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Qml
    Quick
)

# KDE Frameworks
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    CoreAddons
    I18n
    XmlGui
    ConfigWidgets
    KIO
)

add_subdirectory(src)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
```

### Source CMakeLists.txt

```cmake
add_executable(myapp
    main.cpp
    mainwindow.cpp
    mainwindow.h
)

target_link_libraries(myapp PRIVATE
    Qt6::Core
    Qt6::Widgets
    KF6::CoreAddons
    KF6::I18n
    KF6::XmlGui
    KF6::ConfigWidgets
)

install(TARGETS myapp DESTINATION ${KDE_INSTALL_BINDIR})
install(FILES org.kde.myapp.desktop DESTINATION ${KDE_INSTALL_APPDIR})
```

### Plasma Applet CMake

```cmake
add_definitions(-DTRANSLATION_DOMAIN=\"plasma_applet_org.kde.myapplet\")

# Install QML package
plasma_install_package(package org.kde.myapplet)

# Optional C++ plugin
kcoreaddons_add_plugin(myappletplugin SOURCES plugin.cpp INSTALL_NAMESPACE "plasma/applets")
target_link_libraries(myappletplugin PRIVATE
    Qt6::Quick
    KF6::Plasma
)
```

## QML Patterns

### Qt 6 Import Style

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
```

### Basic Kirigami Page

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    title: i18n("My Application")

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: i18n("Main Page")

        actions: [
            Kirigami.Action {
                icon.name: "list-add"
                text: i18n("Add")
                onTriggered: console.log("Add clicked")
            }
        ]

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                text: i18n("Welcome")
                level: 1
            }

            QQC2.Label {
                text: i18n("This is a Kirigami application")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC2.Button {
                text: i18n("Click Me")
                icon.name: "go-next"
                onClicked: pageStack.push(secondPage)
            }
        }
    }

    Component {
        id: secondPage
        Kirigami.Page {
            title: i18n("Second Page")
        }
    }
}
```

### Plasma Applet Main.qml

```qml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Compact representation (in panel)
    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
        }
    }

    // Full representation (popup or desktop)
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10

        PlasmaComponents.Label {
            text: i18n("Hello from Plasma!")
            Layout.alignment: Qt.AlignCenter
        }

        PlasmaComponents.Button {
            text: i18n("Action")
            icon.name: "configure"
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }

    // Tooltip
    toolTipMainText: i18n("My Applet")
    toolTipSubText: i18n("Click to expand")

    Plasmoid.icon: "plasma"
}
```

### Config Dialog

```qml
// contents/config/config.qml
import QtQuick
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_showLabel: showLabelCheckbox.checked
    property alias cfg_labelText: labelTextField.text

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLabelCheckbox
            Kirigami.FormData.label: i18n("Show label:")
        }

        QQC2.TextField {
            id: labelTextField
            Kirigami.FormData.label: i18n("Label text:")
            enabled: showLabelCheckbox.checked
        }
    }
}
```

## KDE Frameworks

### Common Frameworks

| Framework | Purpose |
|-----------|---------|
| `KCoreAddons` | Core utilities, plugins, jobs |
| `KI18n` | Internationalization |
| `KConfig` | Configuration storage |
| `KXmlGui` | Action collections, XML-based UI |
| `KIO` | Network-transparent I/O |
| `KWidgetsAddons` | Extra widgets |
| `KNotifications` | Desktop notifications |
| `Solid` | Hardware abstraction |
| `Kirigami` | Convergent UI framework |
| `KDBusAddons` | DBus helpers |
| `KCrash` | Crash handling |

### Using KConfig

```cpp
// In header
#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>

// Read config
KSharedConfig::Ptr config = KSharedConfig::openConfig();
KConfigGroup group = config->group("General");
QString value = group.readEntry("Key", "default");
int number = group.readEntry("Number", 42);

// Write config
group.writeEntry("Key", "new value");
group.writeEntry("Number", 100);
config->sync();  // Save to disk
```

### Using KIO

```cpp
#include <KIO/Job>
#include <KIO/CopyJob>
#include <KIO/TransferJob>

// Copy file
KIO::CopyJob *job = KIO::copy(sourceUrl, destUrl);
connect(job, &KJob::result, this, [](KJob *job) {
    if (job->error()) {
        qWarning() << job->errorString();
    }
});

// Download file
KIO::TransferJob *job = KIO::get(url);
connect(job, &KIO::TransferJob::data, this, [](KIO::Job*, const QByteArray &data) {
    // Process data chunks
});
```

### i18n Patterns

```cpp
// C++
#include <KLocalizedString>

QString text = i18n("Hello, world!");
QString withArg = i18n("Hello, %1!", name);
QString plural = i18np("One item", "%1 items", count);
QString context = i18nc("Button label", "Open");
```

```qml
// QML
import org.kde.i18n

Text {
    text: i18n("Hello, world!")
}

Text {
    text: i18np("One item", "%1 items", count)
}
```

## Kirigami Components

### Common Components

```qml
// Heading with levels
Kirigami.Heading {
    text: "Title"
    level: 1  // 1-6
}

// Cards
Kirigami.Card {
    banner.source: "image.png"
    banner.title: "Card Title"

    contentItem: QQC2.Label {
        text: "Card content"
    }

    actions: [
        Kirigami.Action {
            text: "Action"
            icon.name: "go-next"
        }
    ]
}

// Inline message
Kirigami.InlineMessage {
    visible: true
    type: Kirigami.MessageType.Warning
    text: i18n("This is a warning")
}

// Loading placeholder
Kirigami.LoadingPlaceholder {
    anchors.fill: parent
}
```

### Units and Spacing

```qml
import org.kde.kirigami as Kirigami

Item {
    width: Kirigami.Units.gridUnit * 10
    height: Kirigami.Units.gridUnit * 5

    spacing: Kirigami.Units.smallSpacing  // 4px
    // Kirigami.Units.mediumSpacing       // 8px
    // Kirigami.Units.largeSpacing        // 12px

    // Icon sizes
    Kirigami.Icon {
        width: Kirigami.Units.iconSizes.small   // 16px
        height: Kirigami.Units.iconSizes.small
        // .smallMedium (22), .medium (32), .large (48), .huge (64), .enormous (128)
    }
}
```

## DBus Integration

### Exposing DBus Interface

```cpp
// Register service
QDBusConnection::sessionBus().registerService("org.kde.myapp");
QDBusConnection::sessionBus().registerObject("/MyApp", this,
    QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
```

### Qt DBus Annotations

```cpp
class MyInterface : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.MyApp")

public slots:
    Q_SCRIPTABLE QString doSomething(const QString &arg);

signals:
    Q_SCRIPTABLE void somethingHappened(const QString &data);
};
```

## Common Patterns

### Main Window with KXmlGui

```cpp
#include <KXmlGuiWindow>
#include <KActionCollection>
#include <KStandardAction>

class MainWindow : public KXmlGuiWindow
{
    Q_OBJECT

public:
    MainWindow()
    {
        // Create actions
        KStandardAction::quit(qApp, &QCoreApplication::quit, actionCollection());
        KStandardAction::preferences(this, &MainWindow::showSettings, actionCollection());

        QAction *myAction = new QAction(QIcon::fromTheme("document-new"), i18n("My Action"), this);
        actionCollection()->addAction("my_action", myAction);
        actionCollection()->setDefaultShortcut(myAction, Qt::CTRL | Qt::Key_N);
        connect(myAction, &QAction::triggered, this, &MainWindow::onMyAction);

        setupGUI();
    }
};
```

### Application main.cpp

```cpp
#include <QApplication>
#include <KAboutData>
#include <KLocalizedString>
#include <KDBusService>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    KLocalizedString::setApplicationDomain("myapp");

    KAboutData about(
        QStringLiteral("myapp"),
        i18n("My Application"),
        QStringLiteral("1.0.0"),
        i18n("Description"),
        KAboutLicense::GPL_V3,
        i18n("Copyright 2024")
    );
    about.addAuthor(i18n("Author Name"), i18n("Developer"), QStringLiteral("email@example.com"));
    KAboutData::setApplicationData(about);

    // Single instance
    KDBusService service(KDBusService::Unique);

    MainWindow window;
    window.show();

    return app.exec();
}
```

## Desktop Integration

### Desktop File

```ini
[Desktop Entry]
Type=Application
Name=My Application
GenericName=File Manager
Comment=Browse and manage files
Exec=myapp %U
Icon=system-file-manager
Terminal=false
Categories=Qt;KDE;Utility;
Keywords=files;folders;
X-KDE-Wayland-Interfaces=org_kde_plasma_window_management
```

### AppStream Metadata

```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>org.kde.myapp</id>
  <name>My Application</name>
  <summary>A brief description</summary>
  <description>
    <p>Longer description of the application.</p>
  </description>
  <url type="homepage">https://kde.org</url>
  <url type="bugtracker">https://bugs.kde.org</url>
  <project_license>GPL-3.0+</project_license>
  <developer_name>KDE</developer_name>
  <screenshots>
    <screenshot type="default">
      <image>https://example.com/screenshot.png</image>
    </screenshot>
  </screenshots>
</component>
```

## Reference Projects

| Project | Location | Good For |
|---------|----------|----------|
| Dolphin | `~/git/reference/dolphin` | File manager, KIO, context menus |
| Plasma Desktop | `~/git/reference/plasma-desktop` | Plasmoids, KCMs, containments |
| Fooyin | `~/git/reference/fooyin` | Qt6 audio player, modern C++ |
| FSearch | `~/git/reference/fsearch` | GTK file search (reference) |

For detailed QML patterns, KConfig XT, and advanced topics, see `qml-reference.md` in this directory.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
