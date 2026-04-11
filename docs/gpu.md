# GPU Hardware Report

Generated: 2026-04-10

## GPU: AMD Radeon RX 6800 XT

**Card:** XFX Speedster MERC 319 AMD Radeon RX 6800 XT Black
**Architecture:** RDNA 2 (Navi 21)
**Driver:** amdgpu (Mesa 26.0.3, DRM 3.64, kernel 6.19.10-arch1-1)

### Memory

- **VRAM:** 16 GB GDDR6 (17,163,091,968 bytes)
- **Visible VRAM:** 16 GB (full BAR / SAM enabled)
- **Memory clocks:** 96 / 456 / 673 / 1000 MHz

### Clocks

- **GPU clock range:** 500 MHz (idle) -- 2575 MHz (boost)

### PCIe

- **Link:** PCIe 4.0 x16 (16.0 GT/s, 16 lanes)

### API Support

- **OpenGL:** 4.6 (Compatibility Profile)
- **GLSL:** 4.60
- **Vulkan:** 1.4.335 (RADV NAVI21)
- **Direct rendering:** Yes

## Ports (4 total)

| Port | Status | Monitor | Resolution |
|------|--------|---------|------------|
| **DP-1** | Connected | BenQ LCD (53x30cm, S/N TCM00859019) | 2560x1440 @ 60 Hz |
| **DP-2** | Connected | ASUS PB278 (60x34cm, S/N D2LMTF022019) | 2560x1440 @ 60 Hz |
| **DP-3** | Disconnected | -- | -- |
| **HDMI-A-1** | Connected | BenQ LCD (53x30cm, S/N TCM00304019) | 2560x1440 @ 60 Hz |

### Protocol Versions

**DisplayPort (DP-1, DP-2, DP-3):** The RX 6800 XT hardware supports
**DisplayPort 1.4a** with DSC (Display Stream Compression). DP 1.4a supports
up to 8.1 Gbps per lane (HBR3), 4 lanes = 32.4 Gbps total, enabling 4K@120Hz
or 8K@60Hz with DSC.

**HDMI (HDMI-A-1):** The RX 6800 XT hardware supports **HDMI 2.1** (up to
48 Gbps, FRL). However, the connected BenQ monitor only advertises HDMI 1.4
capabilities (basic HDMI VSDB, no HF-VSDB block, max dotclock 270 MHz). The
link negotiates at HDMI 1.4 speeds, limited by the monitor.

### Protocol Support Summary

| Interface | GPU Capability | Active Link |
|-----------|---------------|-------------|
| DisplayPort | 1.4a (DSC 1.2a) | 1.4a (HBR3) |
| HDMI | 2.1 (48 Gbps FRL) | 1.4 (monitor-limited, 270 MHz max) |

## Maximum Output Capabilities

- **Max simultaneous displays:** 4 (4 display pipes, DCN 2.1)
- **Max resolution per output:** 8K (7680x4320) @ 60Hz via DP 1.4a with DSC
- **4K@120Hz:** Supported on all ports. DP 1.4a fits 4K@120Hz 8bpc uncompressed
  (25.92 Gbps effective vs ~23.89 Gbps needed). 10bpc requires DSC.
- **4K@144Hz:** Requires DSC over DP 1.4a. HDMI 2.1 handles it uncompressed.
- **3x 4K@120Hz:** Fully supported (3 of 4 display pipes, one per monitor).
  Use 3x DP for cleanest setup. DSC recommended for headroom.
- **DSC:** Supported (Display Stream Compression 1.2a). Visually lossless,
  ~1-2 lines of latency. Monitor must also support DSC decoding.
