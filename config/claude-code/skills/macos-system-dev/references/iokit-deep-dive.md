# IOKit Deep Dive — Apple Silicon Display Hardware

## IOKit Registry Hierarchy for HDMI (MacBook Pro Apple Silicon)

```
AppleATCDPHDMIPort(atc3-dpphy)
├── Properties:
│   ├── DisplayHints: { MaxBpc, EDID UUID, MaxW, ProductName, ... }
│   └── IOClass: "AppleATCDPHDMIPort"
└── Port-HDMI@1 (AppleHDMIPortController)
    └── Properties:
        ├── PortTypeDescription: "HDMI"
        ├── TransportsSupported: ["DisplayPort"]
        ├── TransportsProvisioned: ["DisplayPort"]
        ├── TransportsActive: ["DisplayPort"]  ← KEY: empty when disconnected
        ├── HDMIPortID: 0
        └── IOUserClientClass: "IODPHDMIPortUserClient"
```

## TransportsActive as Connection Indicator

`TransportsActive` on `AppleHDMIPortController` is the most reliable indicator of physical HDMI connection on Apple Silicon Tahoe:

- **Connected**: `["DisplayPort"]` (HDMI uses DisplayPort signaling internally)
- **Disconnected**: `[]` (empty array)

This property updates correctly even when `CGGetActiveDisplayList` keeps the phantom display.

## DCPAVServiceProxy Behavior

`DCPAVServiceProxy` represents the **internal display** on Apple Silicon, managed by the Display CoProcessor (DCP).

- Count is typically 1 (the built-in display)
- **Terminates** when `SkyLight.setDisplayEnabled(builtInID, enabled: false)` is called
- **Matches** when `SkyLight.setDisplayEnabled(builtInID, enabled: true)` is called
- Does NOT represent external HDMI displays
- Does NOT fire events for physical HDMI disconnect

## IOServiceAddInterestNotification Message Types

When registered with `kIOGeneralInterest` on `AppleHDMIPortController`, these message types have been observed:

| messageType (decimal) | Meaning (approximate) |
|----------------------|----------------------|
| 3825172681 | Transport state change (disconnect/connect start) |
| 3825172682 | Transport state change (disconnect/connect complete) |
| 3758096688 | General reconfiguration event |

These fire on both connect and disconnect — check `TransportsActive` to determine direction.

## Debounce Strategy for HDMI Events

HDMI renegotiation causes rapid disconnect/reconnect cycles (display ID churn: 3 → 29 → 3). To distinguish real disconnects from renegotiation:

1. When `TransportsActive` goes empty → start a 2s timer
2. If `TransportsActive` becomes non-empty within 2s → cancel (was renegotiation)
3. If 2s passes and still empty → real disconnect, take action

For the reverse (cable reconnect after auto-recovery):
1. When `TransportsActive` becomes non-empty after being empty → cable reconnected
2. Wait 1s for display to stabilize before restoring state

## Suppression Pattern

SkyLight operations (blackout/reconnect) trigger IOKit state changes on DCPAVServiceProxy and may also trigger interest notifications on `AppleHDMIPortController`. Use a time-based suppression window to ignore events caused by your own operations:

```swift
private var suppressUntil: Date = .distantPast
private func isSuppressed() -> Bool { Date() < suppressUntil }
private func suppress() { suppressUntil = Date().addingTimeInterval(3.0) }

// Call suppress() after any intentional SkyLight operation
func toggle(_ id: CGDirectDisplayID) {
    _ = displayManager.toggleBlackout(displayID: id)
    // Don't suppress here — use countActiveDCPServices() or TransportsActive
    // to distinguish our operation from physical disconnect
}
```

## Display ID Churn on Tahoe

When HDMI renegotiates (cable wiggle, monitor power cycle, display mode change), macOS cycles through transient display IDs:

```
activeIDs=[3]       ← stable (ASUS PB278)
activeIDs=[18]      ← transient (brief renegotiation)
activeIDs=[3]       ← stable again
activeIDs=[19]      ← another transient
activeIDs=[3]       ← back to stable
```

Transient IDs often have fallback names ("Display 18") because IOKit lookup fails during renegotiation. The stable ID (3) has the full name ("ASUS PB278").

Do NOT trigger actions on display ID changes alone — always confirm with a stable check (e.g., `TransportsActive` staying empty for > 2s).

## Exploring IOKit Registry

```bash
# Full tree for a specific class
ioreg -l -r -c AppleHDMIPortController -w0

# All classes in the system (useful for discovering display-related services)
ioreg -l -w0 | grep '"class"' | sort -u

# Search for display-related entries
ioreg -l -w0 | grep -iE 'HDMI|DisplayPort|EDID|Transport' | head -40

# Monitor IOKit changes in real-time (requires developer tools)
# ioreg doesn't have a watch mode — poll with:
watch -n 1 'ioreg -r -c AppleHDMIPortController -w0 | grep TransportsActive'
```
