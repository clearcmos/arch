---
name: macos-system-dev
description: "macOS system programming with Swift — IOKit, CoreGraphics, private frameworks (SkyLight, CoreDisplay), display management, SPM multi-target projects, menu bar apps. Use when working with macOS display APIs, IOKit service matching/notifications, dlopen/dlsym for private frameworks, MenuBarExtra, app bundling, or codesigning. Includes known macOS Tahoe workarounds."
user-invocable: true
disable-model-invocation: false
metadata:
  author: nicholas
  version: 1.0.0
  category: domain-specific-intelligence
---

# macOS System Development Reference

Reference for macOS system-level programming in Swift, covering IOKit hardware interaction, CoreGraphics display management, private framework loading, SwiftUI menu bar apps, and known macOS Tahoe (26.x) bugs and workarounds.

## Critical: macOS Tahoe (26.x) Known Issues

These are verified bugs on macOS 26.x Apple Silicon that WILL waste hours if you don't know them:

1. **CGGetActiveDisplayList keeps phantom HDMI displays** — After physical HDMI disconnect, the display remains in the active list indefinitely. Do NOT rely on `CGGetActiveDisplayList` for physical connection state on Tahoe.
2. **CGDisplayRegisterReconfigurationCallback may not fire** — Known regression on Tahoe where this callback stops working entirely.
3. **CGDisplayIsBuiltin can return wrong values** — After display reconfiguration, the built-in display may get a new ID with incorrect `CGDisplayIsBuiltin` results.
4. **String(format: "%s", ...) crashes** — Swift strings passed to `%s` crash on Tahoe. Use string interpolation with manual padding instead.
5. **IODisplayConnect is empty on Apple Silicon** — Use `IOMobileFramebuffer` service class for display name lookup instead.
6. **NSApplication.didChangeScreenParametersNotification fires but lies** — The notification fires during HDMI renegotiation but `CGGetActiveDisplayList` returns stale data.

## IOKit Patterns

### Service Matching and Enumeration

```swift
import IOKit

// Find services by class name
var iter: io_iterator_t = 0
guard IOServiceGetMatchingServices(
    kIOMainPortDefault,
    IOServiceMatching("AppleHDMIPortController"),
    &iter
) == KERN_SUCCESS else { return }
defer { IOObjectRelease(iter) }

var service = IOIteratorNext(iter)
while service != 0 {
    defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
    // Use service...
}
```

### Reading IOKit Properties

```swift
// Read a specific property from a service
if let val = IORegistryEntryCreateCFProperty(
    service,
    "TransportsActive" as CFString,
    kCFAllocatorDefault, 0
)?.takeRetainedValue() as? [String] {
    print("Active transports: \(val)")
}

// Read all properties
var props: Unmanaged<CFMutableDictionary>?
if IORegistryEntryCreateCFProperties(
    service, &props, kCFAllocatorDefault, 0
) == KERN_SUCCESS {
    let dict = props?.takeRetainedValue() as? [String: Any]
}
```

### IOKit Matching Notifications (Service Creation/Destruction)

Use for watching services that are created/destroyed (e.g., USB devices, display adapters):

```swift
let port = IONotificationPortCreate(kIOMainPortDefault)!
IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

var iter: io_iterator_t = 0
let callback: IOServiceMatchingCallback = { context, iterator in
    var svc = IOIteratorNext(iterator)
    while svc != 0 { IOObjectRelease(svc); svc = IOIteratorNext(iterator) }
    guard let context else { return }
    // Handle event...
}

IOServiceAddMatchingNotification(
    port, kIOTerminatedNotification,  // or kIOMatchedNotification
    IOServiceMatching("ClassName"),
    callback,
    Unmanaged.passUnretained(self).toOpaque(),
    &iter
)
// CRITICAL: drain iterator to arm the notification
var svc = IOIteratorNext(iter)
while svc != 0 { IOObjectRelease(svc); svc = IOIteratorNext(iter) }
```

### IOKit Interest Notifications (Property/State Changes)

Use for watching property changes on persistent hardware nodes that never terminate:

```swift
var interestRef: io_object_t = 0
let cb: IOServiceInterestCallback = { context, service, messageType, arg in
    guard let context else { return }
    // messageType identifies what changed
    // Re-read properties to check new state
}

IOServiceAddInterestNotification(
    port, service, kIOGeneralInterest,
    cb, Unmanaged.passUnretained(self).toOpaque(),
    &interestRef
)
```

**When to use which:**
- `IOServiceAddMatchingNotification` — service appears/disappears from IOKit registry
- `IOServiceAddInterestNotification` — existing service changes state/properties

### Key IOKit Classes for Display Hardware (Apple Silicon)

| Class | Represents | Persists after disconnect? |
|-------|-----------|---------------------------|
| `AppleATCDPHDMIPort` | Physical HDMI port + EDID data | Yes (hardware node) |
| `AppleHDMIPortController` | HDMI port controller, has `TransportsActive` | Yes (hardware node) |
| `DCPAVServiceProxy` | Display CoProcessor AV service (internal display) | Terminates on SkyLight disable |
| `IOMobileFramebuffer` | Framebuffer (use for display names on Tahoe) | Yes |
| `IODisplayConnect` | Display connection (DEPRECATED on Apple Silicon) | N/A |

### Detecting Physical HDMI Disconnect on Tahoe

`CGGetActiveDisplayList` keeps phantom displays. The reliable method is polling `TransportsActive` on `AppleHDMIPortController`:

```swift
func isHDMITransportActive() -> Bool {
    var iter: io_iterator_t = 0
    guard IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("AppleHDMIPortController"),
        &iter
    ) == KERN_SUCCESS else { return false }
    defer { IOObjectRelease(iter) }
    var svc = IOIteratorNext(iter)
    while svc != 0 {
        defer { IOObjectRelease(svc); svc = IOIteratorNext(iter) }
        if let val = IORegistryEntryCreateCFProperty(
            svc, "TransportsActive" as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String], !val.isEmpty {
            return true
        }
    }
    return false
}
```

Combine with `IOServiceAddInterestNotification` on `AppleHDMIPortController` for event-driven detection, with a 1s poll fallback.

## Private Framework Loading (dlopen/dlsym)

### Pattern for Loading Private APIs at Runtime

```swift
import Foundation

enum SkyLight {
    private static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    static var isAvailable: Bool { handle != nil }

    // Typed function pointer wrappers
    static func setDisplayEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) -> CGError {
        typealias Fn_Begin = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>) -> CGError
        typealias Fn_Configure = @convention(c) (UInt32, CGDirectDisplayID, Bool) -> CGError
        typealias Fn_Complete = @convention(c) (UInt32) -> CGError

        guard let h = handle,
              let pBegin = dlsym(h, "SLSBeginDisplayConfiguration"),
              let pConfigure = dlsym(h, "SLSConfigureDisplayEnabled"),
              let pComplete = dlsym(h, "SLSCompleteDisplayConfiguration") else {
            return .failure
        }

        let begin = unsafeBitCast(pBegin, to: Fn_Begin.self)
        let configure = unsafeBitCast(pConfigure, to: Fn_Configure.self)
        let complete = unsafeBitCast(pComplete, to: Fn_Complete.self)

        var token: UInt32 = 0
        var err = begin(0, &token)
        guard err == .success else { return err }
        err = configure(token, displayID, enabled)
        guard err == .success else { return err }
        return complete(token)
    }
}
```

### Guidelines for Private APIs

- Always gate operations on `isAvailable` check
- Load lazily (static let with closure)
- Wrap in typed Swift functions — don't expose raw pointers
- Private APIs can break across macOS versions — test on each target OS
- Common private frameworks: SkyLight (display), CoreDisplay, SkyLightServer

## Display Management (CoreGraphics)

### Display Enumeration

```swift
// Active displays (visible, non-mirrored)
var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
var count: UInt32 = 0
CGGetActiveDisplayList(UInt32(displayIDs.count), &displayIDs, &count)
let active = displayIDs.prefix(Int(count))

// Online displays (includes mirrored, sleeping)
CGGetOnlineDisplayList(UInt32(displayIDs.count), &displayIDs, &count)

// Display properties
let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
let bounds = CGDisplayBounds(displayID)  // CGRect with origin + size
let mainID = CGMainDisplayID()
```

### Display Name Lookup via IOKit (Tahoe-compatible)

`IODisplayConnect` is empty on Apple Silicon. Use `IOMobileFramebuffer`:

```swift
func displayName(for displayID: CGDirectDisplayID) -> String {
    let cgVendor = CGDisplayVendorNumber(displayID)
    let cgProduct = CGDisplayModelNumber(displayID)

    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("IOMobileFramebuffer"),
        &iterator
    ) == KERN_SUCCESS else { return "Display \(displayID)" }
    defer { IOObjectRelease(iterator) }

    var service = IOIteratorNext(iterator)
    while service != 0 {
        defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let attrs = dict["DisplayAttributes"] as? [String: Any],
              let product = attrs["ProductAttributes"] as? [String: Any] else { continue }

        let vendor = product["LegacyManufacturerID"] as? UInt32 ?? 0
        let productID = product["ProductID"] as? UInt32 ?? 0
        if vendor == cgVendor && productID == cgProduct,
           let name = product["ProductName"] as? String {
            return name
        }
    }
    return CGDisplayIsBuiltin(displayID) != 0 ? "Built-in Display" : "Display \(displayID)"
}
```

### Cursor Freeze Pattern

When enabling/disabling displays, freeze the cursor to prevent it jumping:

```swift
func withCursorFreeze<T>(_ body: () -> T) -> T {
    let cursor = CGEvent(source: nil)?.location ?? .zero
    CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
    let result = body()
    Thread.sleep(forTimeInterval: 0.5)
    CGWarpMouseCursorPosition(cursor)
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    return result
}
```

## SwiftUI Menu Bar App

### Basic MenuBarExtra Structure

```swift
import SwiftUI

@main
struct MyMenuBarApp: App {
    @StateObject private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)  // No dock icon
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(appState: appState)
        } label: {
            Image(systemName: "display")
        }
        .menuBarExtraStyle(.window)  // Use .window for custom SwiftUI views
    }
}
```

### Info.plist for LSUIElement (No Dock Icon)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AppName</string>
    <key>CFBundleIdentifier</key><string>com.example.app</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
```

### Instant Hover (No Animation Delay)

Native macOS menus highlight instantly. Don't use `withAnimation` for hover states:

```swift
.onHover { hovering in
    isHovered = hovering  // Instant, no withAnimation wrapper
}
```

### Optimistic Toggle Animation

To animate a toggle visually before a slow operation completes:

```swift
@State private var localActive: Bool  // Drives toggle display

Toggle("", isOn: Binding(
    get: { localActive },
    set: { _ in performToggle() }
))

func performToggle() {
    localActive.toggle()  // Instant visual update
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        onToggle()  // Actual operation after animation completes
    }
}

// Sync local state when external state changes
.onChange(of: isActive) { newValue in localActive = newValue }
```

## SPM Multi-Target Project

### Package.swift with Shared Library + Multiple Executables

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MyKit"),                                    // Shared library
        .executableTarget(name: "mycli", dependencies: ["MyKit"]), // CLI
        .executableTarget(name: "MyBar", dependencies: ["MyKit"]), // Menu bar app
    ]
)
```

### Build Commands

```bash
swift build                                    # Debug build (all targets)
swift build -c release --product mycli         # Release build, specific target
swift build -c release --product MyBar         # Release build, menu bar app
```

### App Bundle Creation

```makefile
bundle: app
    mkdir -p MyApp.app/Contents/MacOS
    cp .build/release/MyBar MyApp.app/Contents/MacOS/
    cp Resources/Info.plist MyApp.app/Contents/
    codesign --force --deep --sign - MyApp.app   # Ad-hoc signing (required on Tahoe)
```

**CRITICAL**: Always codesign after copying the binary. On Tahoe, unsigned binaries are killed with `SIGKILL (Code Signature Invalid)`.

## Debugging Display Issues

### Useful Commands

```bash
# List IOKit services for display hardware
ioreg -l -r -c AppleATCDPHDMIPort -w0
ioreg -l -r -c AppleHDMIPortController -w0
ioreg -l -r -c DCPAVServiceProxy -w0
ioreg -l -r -c IOMobileFramebuffer -w0

# Find display-related IOKit classes
ioreg -l -w0 | grep '"class"' | sort -u | grep -iE 'display|hdmi|dcp|av|clcd|frame'

# Check crash reports
ls ~/Library/Logs/DiagnosticReports/ | grep -i appname

# System log for a process
log show --predicate 'process == "AppName"' --last 5m
```

### State Persistence for Display IDs

Blacked-out display IDs disappear from `CGGetActiveDisplayList`. Persist them to disk:

```swift
// ~/.app_state.json — store blacked-out display IDs
let ids: Set<CGDirectDisplayID> = loadFromDisk()
// On reconnect, these IDs are needed to re-enable displays
```

For detailed IOKit patterns and advanced display management, see `references/iokit-deep-dive.md`.

## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
