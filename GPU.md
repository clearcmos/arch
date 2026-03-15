# AMD RX 6800 XT GPU Configuration

Reference for driver settings, environment variables, kernel parameters, and package requirements for the AMD RX 6800 XT (RDNA2, gfx1030) on Arch Linux with Hyprland (Wayland).

## Packages

### Required (official.txt)

- `mesa` - Mesa 3D graphics library (core graphics stack)
- `vulkan-radeon` - RADV Vulkan driver (Mesa's AMD Vulkan implementation)
- `libva-mesa-driver` - VA-API backend for hardware video decode (H.264, HEVC, VP9, AV1)
- `libva-utils` - VA-API verification tools (`vainfo`)
- `lib32-mesa` - 32-bit Mesa support (needed for 32-bit games via Steam/Lutris)
- `lib32-vulkan-radeon` - 32-bit Vulkan support (needed for 32-bit games)

### Optional (AUR)

- `lact` - AMD GPU management daemon and GUI. Supports fan curves, power limits, undervolting, and overclocking via sysfs. Preferred over CoreCtrl (which is in maintenance mode).

### Diagnostic tools (candidates.txt)

- `vulkan-tools` - Vulkan verification (`vulkaninfo`)
- `radeontop` - Real-time AMD GPU usage monitor
- `clinfo` - OpenCL information tool
- `rocm-smi-lib` - AMD ROCm system management interface

## Environment Variables

Configured in `config/environment.d/10-amd-gpu.conf`, symlinked to `~/.config/environment.d/`.

### Recommended

| Variable | Value | Purpose |
|----------|-------|---------|
| `AMD_VULKAN_ICD` | `RADV` | Use RADV (Mesa's Vulkan driver) over AMDVLK. RADV is faster and better maintained for RDNA2, with active development from Valve and the Mesa community. |
| `LIBVA_DRIVER_NAME` | `radeonsi` | Ensures VA-API uses the correct Mesa driver for hardware video decode instead of falling back to software. |
| `mesa_glthread` | `true` | Offloads OpenGL calls to a separate thread. Significant performance boost in OpenGL apps/games. Mesa enables this automatically for known apps, but setting it globally catches lesser-known titles. |

### Per-game only (do not set globally)

| Variable | Value | Purpose |
|----------|-------|---------|
| `RADV_FORCE_VRS` | `2x2` | Forces Variable Rate Shading on GFX10.3+. Up to 30% fps boost but reduces visual quality at edges. |
| `RADV_TEX_ANISO` | `16` | Forces 16x anisotropic filtering globally in Vulkan apps. |
| `RADV_PERFTEST` | `transfer_queue` | Enables dedicated transfer queue on GFX9+ (Mesa 26.0+). May improve some workloads. |

### Do not set

| Variable | Why |
|----------|-----|
| `RADV_PERFTEST=cswave32,gewave32,pswave32` | No measurable benefit on RDNA2, may cause issues. |
| `RADV_DEBUG=forcecompress` | Can cause artifacts. |

## Kernel Parameters

Configured in `setup.sh` via GRUB_CMDLINE_LINUX_DEFAULT.

### Active

- `amdgpu.gpu_recovery=1` - Enables GPU hang recovery. Good for stability.

### Optional

- `amdgpu.ppfeaturemask` with overdrive bit (`0x4000` OR'd with default) - Unlocks clock/voltage adjustment via sysfs. Required for undervolting/overclocking with LACT or CoreCtrl. To compute the value: `printf '0x%x\n' "$(($(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000))"`. Note: on kernel 6.14+, enabling overdrive taints the kernel as "out of spec."

### Not needed (defaults are correct)

- `amdgpu.dc=1` - Display Core is enabled by default on RDNA2. Required for FreeSync/VRR.
- `amdgpu.dpm=1` - Dynamic Power Management is enabled by default.

### Troubleshooting only

- `amdgpu.runpm=0` - Disables runtime power management. Only if suspend/resume issues occur.
- `amdgpu.sg_display=0` - Fixes screen flickering during resolution changes.
- `amdgpu.dcdebugmask=0x10` - Workaround for unresponsive displays after wake from sleep.

## Hardware Video Decode (VA-API)

The `libva-mesa-driver` package provides VA-API support. Verify with:

```
vainfo
```

You should see decode profiles for H.264, HEVC, VP9, and AV1.

VDPAU was removed from Mesa in 25.3.0. Applications should use VA-API directly. If an app requires VDPAU, `libvdpau-va-gl` provides a translation layer.

## Hyprland Settings

### VRR / FreeSync

```
misc {
    vrr = 1    # 0 = off, 1 = always on, 2 = fullscreen only
}
```

Requires DisplayPort connection and a FreeSync-capable monitor. HDMI FreeSync support varies. If flickering occurs, use `vrr = 2` or `vrr = 0`.

### 10-bit Color

```
monitor = ,preferred,auto,auto,bitdepth,10
```

Not recommended as of early 2026. Still causes black screens and rendering issues on AMD with wlroots/aquamarine. Leave at default 8-bit unless you have a specific HDR/color-critical workflow and are prepared to troubleshoot.

### Explicit Sync

```
render {
    explicit_sync = 2  # 2 = auto (default), works well on AMD
}
```

Do not set to 0 (disabled) on AMD - explicit sync is beneficial.

## Undervolting

The RX 6800 XT benefits from undervolting. Typical results: 50-100mV reduction at stock clocks, lowering temperatures and power draw with no performance loss. Use LACT for a GUI interface to the `pp_od_clk_voltage` sysfs interface. Requires the `ppfeaturemask` overdrive kernel parameter.

## Power Profiles

Available via sysfs at `/sys/class/drm/card0/device/pp_power_profile_mode`:

| ID | Profile |
|----|---------|
| 0 | BOOTUP_DEFAULT |
| 1 | 3D_FULL_SCREEN |
| 2 | POWER_SAVING |
| 3 | VIDEO |
| 4 | VR |
| 5 | COMPUTE |

Performance level at `/sys/class/drm/card0/device/power_dpm_force_performance_level`: `auto` (default, recommended), `high`, or `manual`.

If `power-profiles-daemon` is installed, it may override these values. LACT 0.7.5+ integrates with ppd 0.30+ to avoid conflicts.
