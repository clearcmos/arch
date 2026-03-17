# NixOS to Arch Migration Plan - cmos

Audit of everything configured in `~/nixos/` for host `cmos` that needs to be replicated in `~/arch/`.

Status key: DONE = already in ~/arch, TODO = needs migration, SKIP = not applicable/not wanted, PARTIAL = partially done

---

## 1. Packages

### 1.1 Official Packages (pacman) - DONE

All needed packages added to `packages/official.txt` (single source of truth). archinstall JSON trimmed to boot-minimum. fail2ban SSH jail configured in `config/fail2ban/jail.local` and deployed by `setup.sh`.

Skipped (not wanted): `cpulimit`, `kitty`, `steam`, `mangohud`, `sunshine`, `moonlight-qt`, `jellyfin-media-player`, `p7zip` (have 7zip), `pkg-config` (have pkgconf), `rust-analyzer` (use rustup), `swtpm`, `heroic-games-launcher-bin` (moved to AUR 1.2).

### 1.2 AUR Packages - DONE

Added `webcamoid`, `fooyin`, `devilutionx`, `google-cloud-cli` to `aur.txt`.

Skipped (not wanted): `vesktop-bin`, `wowup-cf`, `heroic-games-launcher-bin`, `droidcam`, `woeusb-ng`.

### 1.3 Python Packages - SKIP

Per-project dependencies. Will be installed in venvs when each service is migrated.

---

## 2. Shell Configuration

### 2.1 Missing Aliases - DONE

From `modules/core/aliases.nix`, not yet in `config/shell/aliases.sh`:

```bash
# Standard
alias ls='ls --color=auto --group-directories-first'
alias compress='tar czf "$(basename "$PWD").tar.gz" .'
alias gen='head -c 45 /dev/urandom | base64 | tr -d "/+="'
alias mine='chown -R $(whoami) .'
alias r='sudo -i'
alias cpath='pwd | wl-copy'
alias addons='cd "/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns"'

# Git helpers
# getrepo - search GitHub repos with fzf, copy SSH URL
```

### 2.2 Missing Shell Functions - DONE

From `modules/core/functions.nix`, these are substantial functions:

| Function | Purpose | Status |
|----------|---------|--------|
| `rm()` | Safe rm wrapper blocking dangerous paths | SKIP - not wanted |
| `port()` | Show listening ports mapped to service names + firewall status | SKIP - ss -tlnp is sufficient |
| `claim-files()` | Find root-owned files, interactively chown | DONE |
| `ghere()` | Interactive grep across codebase | DONE |
| `gc()` | Nix garbage collection analyzer | DONE |

### 2.3 Missing Custom Scripts - TODO

From `modules/core/packages.nix`, these are deployed as system-wide scripts:

| Script | Purpose | Dependencies |
|--------|---------|-------------|
| `flushdns` | Flush DNS cache (resolvectl) | systemd-resolved |
| `check-cert` | Check SSL certificate details | openssl |
| `nuke-secret` | Remove secrets from git history | git-filter-repo |
| `print` | Brother DCP-7060D print (USB + network) | cups, brother drivers |
| `scan2pdf` / `scan2png` | Scanner with AI-powered categorization | sane, tesseract, claude-agent-sdk |
| `pdf-order` | AI-powered PDF organizer | claude-agent-sdk, NAS mount |
| `video` | ffmpeg conversion wrapper | ffmpeg |
| `myspace` | Disk space checker (local + remote hosts) | ssh |
| `shorten` | URL shortener CLI (s.clearcmos.com) | curl, chhoto-url API key |
| `claude-clean` | Claude Code cache cleanup | find |
| `meds` | Medication tracker CLI | curl |
| `mergepdf` | Interactive PDF merger with fzf | qpdf, fzf |
| `fcm-test` | Firebase Cloud Messaging test | python, firebase-admin |

### 2.4 FZF Utilities - DONE

Added `fnano`, `fcd`, `fcat`, `fgrep` to `config/shell/functions.sh`. Skipped `fobsi` (no longer using Obsidian).

### 2.5 Git Commands - DONE

Added `gpush`, `gscan`, `create-repo`, `repo`, `ghelp` as standalone scripts in `config/shell/`, deployed to `~/.local/bin/`. Skipped `gissue` (not wanted).

---

## 3. Systemd Services

### 3.1 Docker - DONE

Docker daemon with overlay2/experimental in `config/docker/daemon.json`. nicholas in docker group. /opt/docker-compose created. Deployed by `setup.sh`.

### 3.2 Cockpit - DONE

Config in `config/cockpit/cockpit.conf`. Port 9090, 4-hour session timeout, LAN CORS origins. Enabled via cockpit.socket in `setup.sh`.

### 3.3 Fail2ban SSH - DONE

Configured in `config/fail2ban/jail.local` and deployed by `setup.sh`. sshd jail: 5 retries in 10min = 1h ban, LAN whitelisted.

### 3.4 Samba - SKIP

Not needed currently.

### 3.5 Borg Backup - SKIP

Deferred for later.

### 3.6 Nextcloud Backup - SKIP

Deferred for later.

### 3.7 Libvirt/KVM Virtualization - TODO

- libvirtd service
- nicholas in libvirtd, kvm, render groups
- VM management commands

### 3.8 Webcam C920 Config - SKIP

Working as-is.

### 3.9 Mouse Button Remap - SKIP

Deferred for later.

### 3.10 USB Hub Bluetooth Toggle - DONE

Udev rules in `config/udev/99-usb-hub-bt-toggle.rules`. System services in `config/systemd/`. Scripts `usb-hub-bt-off` and `usb-hub-bt-on` in `config/shell/`. Deployed by `setup.sh`.

### 3.11 Screen Off + DND (Meta+F10) - DONE

KWin script + user systemd services. `screen-off-toggle` enables DND and turns off screen. `screen-off-watcher` auto-restores notifications on wake. Deployed by `setup.sh` via `config/kwin/setup-kwin-scripts.sh`.

### 3.12 Bluetooth Toggle (Meta+F11) - DONE

KWin script + user systemd service. `bt-toggle` toggles BT on/off with Q30 auto-connect. Deployed by `setup.sh` via `config/kwin/setup-kwin-scripts.sh`.

### 3.13 ChatGPT Quick Input (Meta+F12) - SKIP

Not wanted.

---

## 4. Monitors & Scheduled Tasks

### 4.1 CurseForge Comment Notifier - TODO

- Scrapes CurseForge addon comments with Selenium/Firefox headless
- Posts to Discord webhook
- Timer: 08:00 and 19:00 daily
- State: /var/lib/curseforge-comments

### 4.2 Upstream Issue Monitor - TODO

- Checks GitHub issues for fix signals (e.g., Ollama flash attention on gfx1030)
- Posts to Discord webhook
- Timer: 09:00 and 21:00 daily
- Uses Claude Agent SDK + GitHub PAT

### 4.3 Discord Failure Notify Template - TODO

- Template service: sends Discord webhook on any systemd service failure
- Reads last 20 journal lines
- Reusable via OnFailure= on any service

### 4.4 Rebuild/Update Notification - TODO (adapt)

NixOS sent Discord notifications on rebuild with package diff. Arch equivalent could notify on pacman -Syu with package changes.

### 4.5 Lynis Security Audit - TODO

- Monthly automated security scan
- Reports saved to /var/log/security-scans/lynis
- Custom profile skipping desktop-irrelevant checks

---

## 5. AI/ML Stack

### 5.1 ROCm Infrastructure - TODO

NixOS had:
- rocmPackages: clr, rocm-smi, rocminfo, hipblas, rocblas
- Sysctl: vm.swappiness=10, increased network buffer sizes
- /var/lib/ollama directory
- ollama-validate.sh script
- HSA_OVERRIDE_GFX_VERSION=10.3.0

Arch packages: `rocm-hip-sdk`, `rocm-opencl-sdk`, `radeontop`

### 5.2 Ollama - TODO

- Service on port 11434 (0.0.0.0)
- GPU: rocm-override-gfx=10.3.0
- VRAM limits: 12GB allocated, max 2 loaded models, keep alive indefinitely, low VRAM mode
- Models: qwen2.5-coder:7b, qwen3.5:4b, qwen3-embedding:0.6b, qwen2.5:14b, llava:7b, llama3.2-vision:11b, qwen2.5vl:7b, llama3.1:8b
- Custom model: qwen2.5-coder:tools (temperature=0.15, context=32768)
- GPU memory monitor (unload at 85% VRAM, restart at 95%)
- Cleanup service (every 15min, unload idle models above 70% VRAM)
- Commands: gpu-status, ollama-unload, ollama-safe-load
- Memory limits: MemoryMax=12G, MemoryHigh=10G, CPUQuota=400%

Arch: Install `ollama-rocm` (AUR) or official `ollama` package

### 5.3 LibreChat - TODO

- Docker Compose stack: postgres (pgvector), mongo, librechat, ragapi, mcp
- Data: /mnt/data/librechat
- RAG source: Obsidian vault synced from NAS
- Port 8090 (accessible via WAN with Google OAuth)
- Secrets: encryption-key, jwt-secret, jwt-refresh-secret, postgres-password, mongo-password

### 5.4 SearXNG - TODO

- Privacy metasearch on port 8280
- uWSGI: 4 workers, 4 threads
- JSON API endpoint for AI tool use

### 5.5 Diet MCP Server - TODO

- FastAPI service
- Reads/writes ~/.local/share/diet-db/diet.db

### 5.6 MusicGen (aimusic) - TODO

- Text-to-music generation
- PyTorch ROCm + audiocraft
- Data: /mnt/data/aimusic
- Commands: aimusic, aimusic-web (port 8200), aimusic-status, aimusic-list
- On-demand (not persistent service)

---

## 6. Gaming

### 6.1 Steam - PARTIAL

Lutris, wine-staging, winetricks, gamemode are installed. Missing:
- Steam package itself
- Proton-GE
- Gaming environment variables (WINEFSYNC, WINE_CPU_TOPOLOGY, DXVK_LOG_LEVEL, VKD3D_CONFIG)
- gaming-cleanup shutdown handler (kills Steam/Wine/Lutris on shutdown)
- jemalloc, dxvk, vkd3d packages

### 6.2 WoW Management - TODO

- `wow` command: start, kill, backup, macros
- WoW path: /mnt/data/games/World of Warcraft/_anniversary_
- Backups to /mnt/syno/nextcloud/wow (tar.zst, keeps 5)
- Steam app ID: 2286149340

### 6.3 Sunshine Game Streaming - TODO

- Service: user systemd sunshine
- Config: port 47989, KMS capture, software encoder
- Firewall: TCP 47984,47989,47990,48010 + UDP 47998-48000,8000-8010
- udev rules for uinput/render device access
- nicholas in input, uinput, video, render groups

---

## 7. Application Services

### 7.1 Investment Tracker - TODO

- FastAPI app on port 8003
- SQLite DB: /var/lib/investment-tracker/data.db
- Dedicated user/group
- Auto-payment timers: 1st of every month at 09:00 (mortgage) and 09:05 (RRSP)
- Security hardening (PrivateTmp, ProtectSystem, etc.)
- Secret: investment-tracker-password

### 7.2 System Dashboard - TODO

- FastAPI app on port 8200
- Real-time system monitoring via WebSocket
- Runs as root (systemd status access)

### 7.3 cmos-remote - TODO

- FastAPI app on port 8201
- Endpoints: mute toggle, Bluetooth toggle, status
- Runs as nicholas (audio/BT access)

### 7.4 Docs Site (Mintlify) - TODO

- Mintlify dev server + FastAPI search API
- Combined via nginx on port 3080
- Syncs docs from /mnt/syno/documents/

### 7.5 NixOS Chat - SKIP (NixOS-specific)

### 7.6 Timer CLI + KDE Timer Notifications - TODO

- `t` command: Python timer with FCM notifications
- KDE notification listener for Firebase timer events
- Systemd user service for notifications

### 7.7 Google Tasks TUI - TODO

- `task` command: Google Tasks management
- Needs google-tasks-credentials (age-encrypted)

### 7.8 Twitch TUI - TODO

- twitch-tui with config at ~/.config/twt/config.toml
- Needs twitch-access-token (age-encrypted)

---

## 8. Network Configuration

### 8.1 Bridge Interface (br0) - TODO

NixOS used systemd-networkd with bridge for VM networking:
- br0 bridge with enp8s0 enslaved
- Static IP: 192.168.1.2/24
- Gateway/DNS: 192.168.1.1

Arch currently uses NetworkManager. Decision needed: switch to systemd-networkd for bridge support, or configure bridge in NetworkManager.

### 8.2 Local DNS Entries - DONE

NixOS had /etc/hosts entries:
- money.home.arpa (investment tracker)
- dashboard.home.arpa (system dashboard)
- meds.home.arpa (med tracker)

### 8.3 Firewall - TODO

NixOS firewall (iptables/nftables):
- Base: 22 (SSH), 139/445 (SMB), 5353/5355 (mDNS/LLMNR)
- CMOS additions: 8000, 8001, 8003, 8084, 8200, 8201, 9090, 11434, 27036, 47984-47990, 48010

Arch: Use `ufw` or `nftables` directly

### 8.4 Sysctl Tweaks - TODO

From host/cmos/default.nix:
- `net.bridge.bridge-nf-call-iptables = 0` (Discord RTC fix)
- `net.bridge.bridge-nf-call-ip6tables = 0`
- `net.netfilter.nf_conntrack_udp_timeout = 120`
- `net.netfilter.nf_conntrack_udp_timeout_stream = 180`

From ai/core.nix:
- `vm.swappiness = 10`
- Increased network buffer sizes for AI API traffic

### 8.5 IPv4 Preference - DONE

NixOS had gai.conf to prefer IPv4 (avoid 5s IPv6 fallback). Deploy /etc/gai.conf with IPv4 precedence.

---

## 9. Security

### 9.1 Secrets Management - TODO

NixOS used agenix with 50+ encrypted .age files. Arch needs an equivalent approach:
- age + age-plugin-yubikey are already installed
- Need a secret deployment mechanism (script or tool)
- Key secrets for cmos: borg passphrase, cloudflare creds, discord webhooks, firebase/FCM, investment-tracker password, google-tasks creds, twitch token, github PAT, cifs creds (already done)

### 9.2 Trufflehog Secret Scanning - TODO

- `thog` command: scan git repo for secrets
- `thog-all`: scan filesystem
- Exclusion file for false positives

### 9.3 Security Scanning Tools - TODO

- lynis (monthly audit)
- nmap, rustscan, nuclei
- Custom wrappers: nix-vulnscan, nix-nuclei, traefik-audit

---

## 10. Desktop Environment Tweaks

### 10.1 KDE Services - TODO

From kde.nix:
- `sddm-sync-display-config`: sync multi-monitor to login screen
- `kscreen-apply-config`: apply PLP monitor layout on login
- `kde-icon-fix`: fix icon caching after nix GC (may not apply, but icon caching issues can still happen)

### 10.2 Brave Web Apps - TODO

From host/cmos/default.nix:
- Standalone: Twitch (brave --app=https://twitch.tv)
- Installed apps via --app-id: Messenger, ChatGPT, WhatsApp, Perplexity, Outlook

### 10.3 Brave Shutdown Handler - TODO

- `brave-graceful-shutdown` service: SIGTERM then SIGKILL on system shutdown

### 10.4 Printing & Scanning - TODO

- CUPS with Brother DCP-7060D drivers (brlaser, brgenml1)
- SANE scanner with brscan4
- nicholas in scanner and lp groups

### 10.5 Litra Glow - TODO

- litra-rs (Rust CLI for Logitech Litra Glow/Beam)
- Udev rules for Litra devices (MODE 0660, GROUP video)
- nicholas in video group

### 10.6 Kitty Terminal - TODO

- Config: JetBrains Mono size 11, Catppuccin Mocha theme
- Opacity 0.95, blur 20, powerline tab bar
- Theme switcher script

### 10.7 Konsole Root Profile - TODO

- Root.profile that runs sudo -i
- Breeze theme, 1000 history

### 10.8 Flatpak + Flathub - TODO

- Flatpak service enabled
- Flathub repo added
- Chatterino installed via Flatpak

### 10.9 Claude Desktop - TODO

- AppImage deployment
- Desktop file and icon

---

## 11. Kernel & Boot

### 11.1 Missing Kernel Parameters - DONE

Set: `amdgpu.gpu_recovery=1`, `amdgpu.pcie_atomics=1`, `nmi_watchdog=0`

Skipped: `amdgpu.ppfeaturemask=0xffffffff` - enables unstable GFXOFF (bit 15) causing crashes/artifacts on Navi GPUs. Use `0xffff7fff` if overclocking is needed later.

### 11.2 Kernel Modules - TODO

- `amdgpu` (early load - already handled by default on Arch)
- `v4l2loopback` (virtual webcam)
- `uinput` (mouse remap)
- `i2c-dev` (DDC/CI monitor control)

### 11.3 zram Swap - DONE

Already configured: 15.6G zstd on /dev/zram0.

### 11.4 Disabled Services - DONE

Both wpa_supplicant and ModemManager already disabled.

### 11.5 NTFS Support - DONE (in packages)

Already have unrar/7zip. NTFS is in-kernel since 5.15+.

---

## 12. Environment Variables

### 12.1 Already Set (in environment.d/)

- AMD GPU: HSA_OVERRIDE_GFX_VERSION, GPU_MAX_HEAP_SIZE, etc.
- Wayland: QT_QPA_PLATFORM, GDK_BACKEND, etc.
- Gaming: WINEFSYNC, etc.

### 12.2 Missing - DONE

Deployed in `config/environment.d/30-ai.conf`: AI_API_URL, AI_MODEL, AI_BACKEND_TYPE, AMDGPU_TARGETS, ROCR_VISIBLE_DEVICES.

Skipped: `AMD_VULKAN_ICD=RADV` (redundant, RADV is the only/default driver, AMDVLK is discontinued). Changed `HIP_VISIBLE_DEVICES` to `ROCR_VISIBLE_DEVICES` (correct variable for Linux).

---

## 13. Miscellaneous

### 13.1 Lifestyle Utilities - TODO

- `caffeine` calculator function (coffee mg calculator + detox planner)

### 13.2 Howto AI Helper - TODO

- `howto <command> <inquiry>` - AI-assisted command help using local Ollama + man/tldr pages

### 13.3 Update Checker - PARTIAL

`tools/check-updates.sh` exists but NixOS version was more comprehensive:
- Flake inputs, Docker containers, Flatpak apps, NPM global packages, external binaries, git repos
- Color-coded output

### 13.4 Nix-ld (Run Unpatched Binaries) - SKIP (Arch doesn't need this, NixOS-specific)

### 13.5 Man Page: gissue(1) - TODO

- Custom man page built from markdown via pandoc

### 13.6 nix-update-check - TODO (adapt)

Adapt to check pacman, AUR, flatpak, docker, npm updates

---

## Priority Order

### Phase 1 - Critical Infrastructure
1. Borg backup (data safety)
2. Firewall (security)
3. Fail2ban SSH (security)
4. Docker (many services depend on it)
5. Missing packages (jq, htop, ffmpeg, etc.)
6. Secrets management approach

### Phase 2 - Core Functionality
7. Shell aliases + functions
8. Custom scripts (print, scan, video, etc.)
9. Samba server
10. Bridge networking (br0 for VMs)
11. Sysctl tweaks
12. zram swap
13. Kernel parameters + modules

### Phase 3 - AI/ML Stack
14. ROCm infrastructure
15. Ollama (service + model management)
16. SearXNG
17. LibreChat (Docker Compose)
18. Diet MCP server

### Phase 4 - Application Services
19. Investment tracker
20. System dashboard
21. cmos-remote
22. Timer CLI + notifications
23. Google Tasks TUI
24. Twitch TUI

### Phase 5 - Desktop Polish
25. KWin shortcuts (Meta+F10/F11/F12)
26. Mouse remap (Razer Viper Mini)
27. USB hub BT toggle
28. Webcam C920 config
29. Litra Glow udev
30. Kitty terminal config
31. Brave web apps + shutdown handler
32. Printing/scanning (CUPS + Brother)
33. Flatpak + Chatterino
34. Claude Desktop AppImage

### Phase 6 - Monitoring & Automation
35. Discord failure notify template
36. CurseForge comment notifier
37. Upstream issue monitor
38. Lynis monthly audit
39. Update notification (adapted)
40. Docs site (Mintlify)

### Phase 7 - Gaming
41. Steam + Proton-GE
42. WoW management (wow command)
43. Sunshine game streaming
44. Gaming shutdown handler

### Phase 8 - VM Infrastructure
45. Libvirt/KVM setup
46. nixvm disk provisioner
47. VM management commands

---
---

# Appendix A - Detailed Reference

Everything below contains exact values, configs, and source file locations needed during implementation.

---

## A1. Brave Browser - Exact Configuration

### GPU Stability Flags (wrap brave binary or use brave-flags.conf)
```
--use-gl=angle
--disable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder
```

Environment: `QT_NO_GLIB=1` (prevents Qt6 SIGTRAP crash)

### Extension CRX IDs (install via policy)
```
aeblfdkhhhdcdjpifhhbdiojplfjncoa
cjpalhdlnbpafiamejdnhcphjbkeiagm
jcokdfogijmigonkhckmhldgofjmfdak
mmpokgfcmbkfdeibafoafkiijdbfblfg
mmioliijnhnoblpgimnlajmefafdfilb
```

### Brave Policies (deployed to /etc/brave/policies/managed/policies.json)
```json
{
  "BrowserSignin": 0,
  "SyncDisabled": true,
  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "DefaultBrowserSettingEnabled": true,
  "MetricsReportingEnabled": false,
  "SearchSuggestEnabled": false,
  "SpellcheckEnabled": true,
  "SpellcheckLanguage": ["en-US", "en-CA", "fr"],
  "RestoreOnStartup": 1,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Google",
  "DefaultSearchProviderSearchURL": "https://www.google.com/search?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://www.google.com/complete/search?output=chrome&q={searchTerms}",
  "DefaultSearchProviderIconURL": "https://www.google.com/favicon.ico",
  "DefaultSearchProviderKeyword": "google",
  "BraveRewardsDisabled": true,
  "BraveTodayDisabled": true,
  "BraveAdblockEnabled": true
}
```

### Default MIME Applications (xdg-mime)
```
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
text/html=brave-browser.desktop
application/xhtml+xml=brave-browser.desktop
application/pdf=brave-browser.desktop
```

### Web App Definitions

Standalone (separate Brave profile):
- Twitch: `brave --app=https://twitch.tv --user-data-dir=~/.local/share/brave-twitch`

Installed apps (via default profile --app-id):
| App | App ID |
|-----|--------|
| Messenger | `bbdeiblfgdokhlblpgeaokenkfknecgl` |
| ChatGPT | `cadlkienfkclaiaibeoongdcgmdikeeg` |
| WhatsApp | `hnpfjngllnobngcgfapefoaidbinmjnm` |
| Perplexity | `kpmdbogdmbfckbgdfdffkleoleokbhod` |
| Outlook | `eigpmdhekjlgjgcppnanaanbdmnlnagl` |

### Brave Graceful Shutdown Service
Systemd service that sends SIGTERM to all Brave processes before system shutdown, waits 5s, then SIGKILL. Prevents session corruption.

---

## A2. Bluetooth - Exact Configuration

### Hardware
- Headphones: Soundcore Life Q30, MAC `E8:EE:CC:46:F1:AC`
- Adapter: Intel AX211 (requires btusb workaround)

### btusb Module Option - SKIP
`disable_msft_ext` is not a real btusb parameter (kernel patch was proposed but rejected). The BLE-only connection issue is fixed via `ControllerMode = bredr` in `/etc/bluetooth/main.conf` instead.

### PipeWire/WirePlumber Bluetooth Codecs - DONE
Deployed to `~/.config/wireplumber/wireplumber.conf.d/51-bluez-config.conf` via `config/wireplumber/51-bluez-config.conf` (WirePlumber 0.5 SPA JSON format).

### Bluetooth Main Config - DONE
Deployed to `/etc/bluetooth/main.conf` via `config/bluetooth/main.conf`.

### bt-toggle Script - TODO
Toggles Bluetooth on/off. When enabling, auto-connects Q30 (E8:EE:CC:46:F1:AC). Uses libnotify for status. Exposed as KWin Meta+F11 shortcut via D-Bus to systemd user service.

---

## A3. SSH - Exact Known Hosts

Deploy to `~/.ssh/known_hosts` and/or `/etc/ssh/ssh_known_hosts`:

```
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
cmos.home.arpa,192.168.1.2 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWApzyGnR1dTPKRy2+5pprZa8W1ICPmTN26Yf10kuCH
misc.home.arpa,192.168.1.5 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKsqrFBWZUo0F2e5U6V/sDE+k5q9VSprdHmCdhnT2bhd
jimmich.home.arpa,192.168.1.10 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Vu33OgWjxAcWrq11UaXIQDNJuCq1psIcNO1v0BOhI
nixvm.home.arpa,192.168.1.14 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPD9O2Kp035SnwfDKlDicTr6Xf/kUL4L4igoEgL2WrMA
```

### SSH Server Config (already deployed, for reference)
- PermitRootLogin: yes (needed for deployment)
- PasswordAuthentication: false
- PubkeyAuthentication: true
- MaxAuthTries: 3
- LoginGraceTime: 30
- ClientAliveInterval: 300 (5 min)
- ClientAliveCountMax: 2
- AllowUsers: nicholas root
- WAN (non-192.168.1.0/24): AllowUsers=nobody, no auth methods (effectively blocked)

---

## A4. Sysctl - All Values

### CMOS-specific (host/cmos/default.nix)
```ini
# Discord RTC fix on bridge interface
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0

# WebRTC/voice UDP timeouts
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 180
```

### AI/ML workload tuning (ai/core.nix)
```ini
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

### Kernel (core/kernel-tweaks.nix)
```ini
nmi_watchdog = 0
```

### Already deployed (config/sysctl/99-quiet-console.conf)
```ini
kernel.printk = 3 3 3 3
```

---

## A5. Secrets Inventory (CMOS-only)

All secrets were managed by agenix (age-encrypted, decrypted at boot). For Arch, these need a deployment approach (age + YubiKey decrypt script, or manual placement).

### Critical (Phase 1)
| Secret | Mode | Owner | Used By |
|--------|------|-------|---------|
| `borg-backup-passphrase` | 0600 | root | Borg backup service |
| `cifs-username` | 0600 | root | NAS mount (DONE - /etc/cifs/credentials) |
| `cifs-password` | 0600 | root | NAS mount (DONE - /etc/cifs/credentials) |
| `github-pat` | 0640 | root:github-access | Git commands, issue monitors |

### Discord Webhooks
| Secret | Mode | Owner | Used By |
|--------|------|-------|---------|
| `discord-webhook-url` | 0600 | nicholas | Upstream monitors, failure notify |
| `discord-webhook-rebuilds` | 0600 | root | Update notifications |
| `curseforge-discord-webhook` | 0600 | nicholas | CurseForge comment notifier |

### Firebase/FCM
| Secret | Mode | Owner | Used By |
|--------|------|-------|---------|
| `firebase-service-account` | 0640 | root:fcm-access | Timer CLI, KDE timer notifications |
| `fcm-device-phone-token` | 0640 | root:fcm-access | Timer CLI (push to phone) |

### Application Secrets
| Secret | Mode | Owner | Used By |
|--------|------|-------|---------|
| `investment-tracker-password` | 0400 | investment-tracker | Investment tracker auth |
| `google-tasks-credentials` | 0400 | nicholas | Google Tasks TUI |
| `twitch-access-token` | 0600 | nicholas | Twitch TUI (format: oauth:xxx) |
| `cloudflare-credentials` | 0640 | root:cloudflare-access | cf-delete, cf-list scripts |
| `nvd-api-key` | 0640 | root:users | Vulnerability scanning |
| `searxng-secret-key` | 0600 | root | SearXNG service |

### LibreChat (Docker)
| Secret | Mode | Owner | Used By |
|--------|------|-------|---------|
| `librechat-encryption-key` | 0600 | librechat | LibreChat encryption |
| `librechat-jwt-secret` | 0600 | librechat | JWT signing |
| `librechat-jwt-refresh-secret` | 0600 | librechat | JWT refresh |
| `librechat-postgres-password` | 0600 | librechat | Postgres auth |
| `librechat-mongo-password` | 0600 | librechat | MongoDB auth |

### SSH Keys (per-host, from agenix)
| Secret | Path | Note |
|--------|------|------|
| `cmos-nicholas-private-key` | ~/.ssh/id_ed25519 | DONE (restored from NAS via age+YubiKey) |
| `cmos-root-private-key` | /root/.ssh/id_ed25519 | Needs deployment for root SSH |

---

## A6. Application Source Code Locations

All app source code lives in `~/nixos/apps/`. These directories need to be copied or referenced when setting up services.

| App | Location | Language | Framework | Port | Database |
|-----|----------|----------|-----------|------|----------|
| cmos-remote | `~/nixos/apps/cmos-remote/server/` | Python | FastAPI | 8201 | None |
| diet-db | `~/nixos/apps/diet-db/` | Python | FastAPI (MCP) | 8112 | SQLite: ~/.local/share/diet-db/diet.db |
| google-tasks-tui | `~/nixos/apps/google-tasks-tui/` | Python | Rich CLI | N/A | None (Google API) |
| investment-tracker | `~/nixos/apps/investment-tracker/` | Python+React | FastAPI+Vite | 8003 | SQLite: /var/lib/investment-tracker/data.db |
| kde-timer-notifications | `~/nixos/apps/kde-timer-notifications/` | Python | Firebase+D-Bus | N/A | Firebase RTDB |
| med-tracker | `~/nixos/apps/med-tracker/` | Python | FastAPI | 8110 | SQLite: /var/lib/med-tracker/meds.db |
| system-dashboard | `~/nixos/apps/system-dashboard/` | Python+JS | FastAPI+WebSocket | 8200 | None (reads systemd) |
| timer-cli | `~/nixos/apps/timer-cli/` | Python | Google Cloud Tasks | N/A | Cloud Tasks queue |
| timer-cloud-function | `~/nixos/apps/timer-cloud-function/` | Python | Cloud Functions | N/A | Firebase RTDB |
| fcm-notifier | `~/nixos/apps/fcm-notifier/` | Kotlin | Jetpack Compose | N/A | Android app |

Note: `nixos-chat` is NixOS-specific (SKIP). `firebase-test` is a static HTML test page.

---

## A7. Scripts Inventory (~/nixos/scripts/)

### Bash Scripts

| Script | Purpose | Dependencies | Used By |
|--------|---------|-------------|---------|
| `claude-nas-backup.sh` | Backs up ~/.claude settings/skills/memory to /mnt/syno/claude-backup | rsync | Manual / alias `claude-nas` |
| `nuke-secret.sh` | Remove secrets from git history with backup branch | git, git-filter-repo | Manual CLI `nuke-secret` |
| `pdf-order.sh` | Organize PDFs into /mnt/syno/scans/ using Ollama vision + ocrmypdf | curl, imagemagick, ocrmypdf, ollama | Manual CLI `pdf-order` |
| `scan2pdf.sh` | Scan to searchable PDF with AI-powered filing | scanimage (sudo), tesseract, imagemagick, ollama or Claude API | Manual CLI `scan2pdf` |
| `scan2png.sh` | Scan to PNG with AI-powered filing | scanimage (sudo), imagemagick, ollama | Manual CLI `scan2png` |
| `test-rocm.sh` | Validate ROCm/GPU setup | rocminfo, radeontop, lspci | Manual diagnostic |
| `traefik-audit.sh` | Security audit of Traefik logs on misc | ssh (misc.home.arpa), journalctl | Manual CLI `traefik-audit` |
| `video.sh` | Discord video converter (two-pass x264, 10MB limit) | ffprobe, ffmpeg, wl-copy | Manual CLI `video` |
| `create-jellyfin-users-secret.sh` | Generate Jellyfin user secrets | python3, agenix | One-time setup (jimmich) |
| `migrate-media-config.sh` | Migrate Radarr/Sonarr databases | sqlite3, systemctl | One-time migration |
| `rekey-nixvm.sh` | Re-encrypt agenix secrets for nixvm | age, agenix | One-time NixOS maintenance |

### Python Scripts

| Script | Purpose | Dependencies | Used By |
|--------|---------|-------------|---------|
| `backup-nextcloud.py` | Backup Nextcloud data to Google Drive | rclone, tar, zstd | Systemd timer (nightly 4 AM) |
| `backup-secrets.py` | Backup agenix secrets to 1Password/GDrive/NAS | rclone, age, age-plugin-yubikey, op (1Password CLI) | Systemd timer |
| `check-keycloak-security.py` | Monitor Keycloak CVEs | ssh, gh, Claude Agent SDK | Systemd timer + Discord |
| `check-mesa-dx11-fix.py` | Monitor Mesa for WoW DX11 fix on RX 6800 XT | Claude Agent SDK, urllib | Systemd timer + Discord |
| `check-traefik-security.py` | Monitor Traefik CVEs | ssh, gh, Claude Agent SDK | Systemd timer + Discord |
| `check-upstream-issues.py` | Track GitHub issues for fix signals | gh CLI, Claude Agent SDK | Systemd timer + Discord |
| `curseforge-comments.py` | Scrape CurseForge addon comments | selenium, firefox, geckodriver | Systemd timer (08:00, 19:00) |
| `fcm-test.py` | Send test FCM notifications | firebase-admin | Manual CLI `fcm-test` |
| `litra-control.py` | TUI for Logitech Litra Glow | textual, rich, litra CLI | Manual CLI |
| `nix-pentest.py` | Pentest suite for bedrosn.com | nmap, nuclei, rustscan, lynis | Manual CLI |
| `portfolio-gate.py` | TOTP-gated portfolio HTTP server | stdlib (http.server, hmac) | Systemd service (misc) |
| `scan-claude-file.py` | AI-powered PDF filing using Claude | Claude Agent SDK | Called by scan2pdf.sh --claude |
| `scan-smart-file.py` | AI-powered PDF filing using Ollama | ollama (localhost:11434) | Called by scan2pdf.sh, scan2png.sh |
| `security_monitor_base.py` | Shared library for security monitors | Claude Agent SDK, gh, urllib | Imported by check-*.py scripts |
| `generate-jellyfin-users.py` | Generate Jellyfin user configs | stdlib | Called by create-jellyfin-users-secret.sh |
| `backup-*.py` (other) | Various backup utilities | rclone, rsync | Systemd timers |

### Scripts Relevant to Arch Migration (need to copy/adapt)
- `claude-nas-backup.sh` - works as-is
- `nuke-secret.sh` - works as-is
- `pdf-order.sh` - works once Ollama is running
- `scan2pdf.sh`, `scan2png.sh` - need scanimage (sane), tesseract, imagemagick
- `scan-smart-file.py`, `scan-claude-file.py` - called by scan scripts
- `video.sh` - works once ffmpeg installed
- `traefik-audit.sh` - works as-is (SSHs to misc)
- `backup-nextcloud.py` - works once rclone configured
- `backup-secrets.py` - needs adaptation (no more agenix)
- `check-upstream-issues.py` - works with Claude Agent SDK + github-pat
- `curseforge-comments.py` - needs selenium, firefox, geckodriver
- `litra-control.py` - needs textual, litra-rs
- `security_monitor_base.py` - shared library, copy alongside check-*.py
- `fcm-test.py` - works with firebase-admin

### Scripts NOT Relevant to Arch (NixOS/server-specific)
- `create-jellyfin-users-secret.sh` - jimmich host
- `generate-jellyfin-users.py` - jimmich host
- `migrate-media-config.sh` - one-time, already done
- `rekey-nixvm.sh` - NixOS agenix specific
- `portfolio-gate.py` - runs on misc host
- `check-keycloak-security.py` - monitors misc service
- `check-traefik-security.py` - monitors misc service
- `check-mesa-dx11-fix.py` - can keep if WoW DX11 bug still relevant
- `nix-pentest.py` - references NixOS infra, needs adaptation

---

## A8. Tailscale VPN

NixOS had: `services.tailscale.enable = true` + `tailscale` package.

Arch setup:
1. Install `tailscale` (official repos)
2. `systemctl enable --now tailscaled`
3. `tailscale up` (authenticate via browser)
4. Firewall: Tailscale manages its own interface (tailscale0), no manual rules needed

---

## A9. KDE Google Drive Integration

NixOS had a custom signond + signon-plugin-oauth2 + signon-ui stack for KDE Online Accounts to access Google Drive in Dolphin via kio-gdrive.

Arch packages needed:
- `kaccounts-integration` (official)
- `kaccounts-providers` (official)
- `kio-gdrive` (official)
- `signond` (AUR: `signon-daemon`)
- `signon-plugin-oauth2` (AUR: `signon-plugin-oauth2`)
- `signon-ui` (AUR: `signon-ui` or `signon-ui-git`)

This was complex on NixOS (custom package builds, D-Bus service wrappers). On Arch it should be simpler - install the AUR packages and KDE Online Accounts should work. May need to add Google account via System Settings > Online Accounts.

---

## A10. Ollama - Full Service Configuration

### Systemd Environment Variables
```ini
OLLAMA_HOST=0.0.0.0:11434
HSA_OVERRIDE_GFX_VERSION=10.3.0
OLLAMA_GPU_MEMORY=12GB
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_KEEP_ALIVE=-1
OLLAMA_LOW_VRAM=1
```

### Systemd Resource Limits (override)
```ini
[Service]
MemoryMax=12G
MemoryHigh=10G
CPUQuota=400%
Nice=10
```

### Models to Preload
```
qwen2.5-coder:7b
qwen3.5:4b
qwen3-embedding:0.6b
qwen2.5:14b
llava:7b
llama3.2-vision:11b
qwen2.5vl:7b
llama3.1:8b
```

### Custom Model: qwen2.5-coder:tools
Modelfile:
```
FROM qwen2.5-coder:7b-instruct
PARAMETER temperature 0.15
PARAMETER num_ctx 32768
```

### GPU Memory Monitor Service
- Runs continuously
- At 85% VRAM: unloads least-recently-used models
- At 95% VRAM: restarts Ollama service
- Commands: `gpu-status`, `ollama-unload`, `ollama-safe-load`

### Ollama Cleanup Timer
- Every 15 minutes
- Unloads idle models when VRAM > 70%

---

## A11. Firewall - Complete Port Map

### Base (all hosts on NixOS, apply to Arch)
| Port | Proto | Service |
|------|-------|---------|
| 22 | TCP | SSH |
| 139 | TCP | SMB/CIFS |
| 445 | TCP | SMB/CIFS |
| 5353 | UDP | mDNS |
| 5355 | UDP | LLMNR |

### CMOS Desktop
| Port | Proto | Service |
|------|-------|---------|
| 8000 | TCP | Keeper app API |
| 8001 | TCP | radeontop-web |
| 8003 | TCP | Investment tracker |
| 8084 | TCP | Claude Code WebUI |
| 8112 | TCP | Diet MCP server |
| 8200 | TCP | System dashboard |
| 8201 | TCP | cmos-remote |
| 9090 | TCP | Cockpit |
| 11434 | TCP | Ollama |

### Gaming/Streaming
| Port | Proto | Service |
|------|-------|---------|
| 27036 | TCP | Steam Remote Play |
| 47984 | TCP | Sunshine HTTPS |
| 47989 | TCP | Sunshine HTTP |
| 47990 | TCP | Sunshine Web |
| 48010 | TCP | Sunshine RTSP |
| 47998-48000 | UDP | Sunshine media |
| 8000-8010 | UDP | Sunshine audio |

### AI Stack
| Port | Proto | Service |
|------|-------|---------|
| 8090 | TCP | LibreChat |
| 8098 | TCP | LibreChat MCP |
| 8099 | TCP | LibreChat RAG API |
| 8280 | TCP | SearXNG |
| 9222 | TCP | Brave CDP (localhost only, ChatGPT Quick) |

---

## A12. Printing & Scanning - Exact Setup

### Printer: Brother DCP-7060D
- USB (default): auto-detected by CUPS
- Network via router: `socket://192.168.1.1:9100`
- Drivers: `brlaser` (official), `brgenml1cupswrapper`, `brgenml1lpr` (AUR: `brother-dcp7060d`)

### Scanner: Brother DCP-7060D
- SANE backend: `brscan4` (AUR: `brscan4`)
- Requires: nicholas in `scanner` and `lp` groups
- scanimage requires sudo (Brother driver limitation)
- Sudo NOPASSWD rule: `nicholas ALL=(ALL) NOPASSWD: /usr/bin/scanimage`

### CUPS Setup
```bash
# Install
pacman -S cups

# Enable
systemctl enable --now cups

# Add printer (USB)
# Auto-detected, or manually via CUPS web UI at localhost:631

# Add printer (network)
lpadmin -p Brother-DCP7060D -E -v socket://192.168.1.1:9100 -m everywhere
```

---

## A13. Litra Glow - Udev Rules

Deploy to `/etc/udev/rules.d/99-litra.rules`:
```
# Logitech Litra Glow
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c900", MODE="0660", GROUP="video"
# Logitech Litra Beam
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c901", MODE="0660", GROUP="video"
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="b901", MODE="0660", GROUP="video"
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c903", MODE="0660", GROUP="video"
```

Install `litra` from cargo: `cargo install litra` (from timrogers/litra-rs v2.4.0)

---

## A14. Kitty Terminal - Config

Deploy to `~/.config/kitty/kitty.conf`:
```
font_family JetBrains Mono
font_size 11
background_opacity 0.95
background_blur 20
tab_bar_style powerline
tab_bar_min_tabs 1
tab_bar_edge top
shell_integration enabled

# Catppuccin Mocha colors
foreground #CDD6F4
background #1E1E2E
selection_foreground #1E1E2E
selection_background #F5E0DC
cursor #F5E0DC
cursor_text_color #1E1E2E
url_color #F5E0DC

# Normal colors
color0 #45475A
color1 #F38BA8
color2 #A6E3A1
color3 #F9E2AF
color4 #89B4FA
color5 #F5C2E7
color6 #94E2D5
color7 #BAC2DE

# Bright colors
color8 #585B70
color9 #F38BA8
color10 #A6E3A1
color11 #F9E2AF
color12 #89B4FA
color13 #F5C2E7
color14 #94E2D5
color15 #A6ADC8
```

---

## A15. Webcam C920 - Systemd Service

Oneshot service to configure Logitech C920 on boot:
```ini
[Unit]
Description=Configure Logitech C920 Webcam
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=MJPG
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

---

## A16. Mouse Remap (Razer Viper Mini) - Details

### Kernel Module
Load `uinput`: add to `/etc/modules-load.d/uinput.conf`

### Python Script
Uses `evdev` library. Reads from `/dev/input/by-id/usb-Razer_Razer_Viper_Mini-event-mouse`.
- BTN_EXTRA (code 276) tap (< 0.2s): sends original BTN_EXTRA
- BTN_EXTRA (code 276) hold (>= 0.2s): acts as Left Control modifier

### Systemd Service
```ini
[Unit]
Description=Mouse tap-hold remap for Razer Viper Mini

[Service]
Type=simple
ExecStart=/usr/bin/python3 /path/to/mouse-remap.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

---

## A17. USB Hub Bluetooth Toggle - Details

### Hardware
- VIA Labs USB 2.0 Hub: vendor `2109`, product `2817`
- Q30 MAC: `E8:EE:CC:46:F1:AC`

### Udev Rules (deploy to /etc/udev/rules.d/99-usb-hub-bt.rules)
```
# USB hub removed - disable bluetooth
ACTION=="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="2109", ATTR{idProduct}=="2817", RUN+="/usr/bin/systemctl start --no-block usb-hub-bt-off.service"

# USB hub added - enable bluetooth
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2109", ATTR{idProduct}=="2817", RUN+="/usr/bin/systemctl start --no-block usb-hub-bt-on.service"
```

### Two Systemd Services
- `usb-hub-bt-off`: Turns BT off, idempotent
- `usb-hub-bt-on`: Turns BT on, auto-connects Q30, idempotent

---

## A18. KWin Script Pattern

All three shortcuts (Meta+F10/F11/F12) follow the same pattern:

1. Create KWin script directory: `~/.local/share/kwin/scripts/<name>/`
2. Write `metadata.json` (KPackageStructure format for Plasma 6)
3. Write `main.js` that registers a shortcut calling D-Bus to start a systemd user service
4. Enable the KWin script via `kwriteconfig6`

Example main.js:
```javascript
registerShortcut("Toggle Something", "Toggle Something", "Meta+F11", function() {
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
             "org.freedesktop.systemd1.Manager", "StartUnit",
             "my-service.service", "replace");
});
```

---

## A19. Cockpit - Exact Configuration

Deploy to `/etc/cockpit/cockpit.conf`:
```ini
[WebService]
LoginTitle = cmos
AllowUnencrypted = true
Origins = https://localhost https://cmos.home.arpa https://cmos-pit.bedrosn.com
IdleTimeout = 240

[Session]
Banner = /etc/cockpit/issue
```

Port 9090. Firewall rule needed. Package: `cockpit` (official repos).

---

## A20. Fail2ban - Exact Jail Configuration

Deploy to `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime = 1h
backend = systemd
ignoreip = 127.0.0.0/8 ::1 192.168.1.0/24

[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h

[sshd-flood]
enabled = true
filter = sshd
maxretry = 10
findtime = 1m
bantime = 3h
```

Helper scripts:
- `fail2ban-ssh-status`: show banned IPs and jail status
- `fail2ban-ssh-unban <IP>`: unban specific IP

---

## A21. Borg Backup - Exact Configuration

### Backup Paths
```
/etc
/home/nicholas/.bash_history
/home/nicholas/.config  (KDE configs)
/home/nicholas/.ssh
/home/nicholas/.claude
/home/nicholas/.local/share/diet-db
/home/nicholas/Desktop
/home/nicholas/Documents
/home/nicholas/git
/home/nicholas/Pictures
/home/nicholas/Videos
/root/.gnupg
/root/.ssh
```

### Exclusion Patterns
```
*/node_modules
*/.venv
*/__pycache__
*/build
*/dist
*/target
*/.next
*/venv
*/repos     (nixos/repos)
*/reference (git/reference)
```

### Local Backup
- Repo: `/mnt/data/backups/cmos/borg`
- Encryption: `repokey-blake2`
- Compression: `zstd,3`
- Retention: 14 daily
- Timer: daily at 05:00 with 5min random delay

### Remote Backup
- Repo: `nicholas@offsite.bedrosn.com:/mnt/data/cmos/borg`
- Same encryption/compression/retention
- Triggers after local backup succeeds

### Manual Commands
- `backup-cmos-manual-borg` - on-demand timestamped archive
- `backup-cmos-manual-borg-dry` - dry run

---

## A22. Samba - Exact Configuration

### smb.conf (relevant sections)
```ini
[global]
server min protocol = SMB2
server max protocol = SMB3
disable netbios = yes
dns proxy = no
map to guest = never
encrypt passwords = yes
security = user

[cmos-home]
path = /home/nicholas
valid users = nicholas
read only = no
browseable = yes
```

### User Setup
```bash
sudo smbpasswd -a nicholas
```

Packages: `samba` (official). Enable: `systemctl enable --now smb nmb wsdd2`

---

## A23. Docker - Exact Configuration

### daemon.json (deploy to /etc/docker/daemon.json)
```json
{
  "storage-driver": "overlay2",
  "experimental": true
}
```

### Setup
```bash
# Packages: docker, docker-compose, docker-buildx
systemctl enable --now docker
usermod -aG docker nicholas
mkdir -p /opt/docker-compose
chown nicholas:docker /opt/docker-compose
chmod 755 /opt/docker-compose
```

---

## A24. Suricata Management CLI

Command available on cmos for managing Clear NDR suppression rules on misc host:
- `suricata --suppress-add <SIG_ID>` - Add suppression rule
- `suricata --suppress-remove <SIG_ID>` - Remove rule
- `suricata --suppress-list` - List all rules
- `suricata --suppress-edit` - Edit in $EDITOR

Edits `/etc/nixos/modules/services/clear-ndr.nix` on misc via SSH, then prompts to rebuild. May need adaptation for non-NixOS misc host.

---

## A25. Trufflehog - Wrapper Commands

### thog (git scan)
```bash
trufflehog git file://. --only-verified --exclude-paths=/path/to/trufflehog-exclude.txt
```

### thog-all (filesystem scan)
```bash
trufflehog filesystem . --only-verified --exclude-paths=/path/to/trufflehog-exclude.txt
```

Install: `trufflehog` (AUR or download binary from GitHub). Exclusion file should filter: `.age` files, test fixtures, known false positives.

Also symlink exclusion config to `~/.truffleignore`.

---

## A26. Konsole Root Profile

Deploy to `~/.local/share/konsole/Root.profile`:
```ini
[Appearance]
ColorScheme=Breeze
Font=Monospace,11

[General]
Command=sudo -i
Name=Root
Parent=FALLBACK/

[Scrolling]
HistorySize=1000

[Terminal Features]
UrlHintsModifiers=0
```

Deploy to `~/.config/konsolerc`:
```ini
[Desktop Entry]
DefaultProfile=Root.profile
```

---

## A27. Konsole cpv Utility

`cpv` command: copies visible text from active Konsole tab to clipboard via D-Bus.
```bash
cpv() {
    qdbus6 org.kde.konsole-$KONSOLE_DBUS_SESSION \
        /Sessions/$(qdbus6 org.kde.konsole-$KONSOLE_DBUS_SESSION /Windows/1 currentSession) \
        org.kde.konsole.Session.visibleText | wl-copy
}
```
