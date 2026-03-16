# NixOS to Arch Migration Plan - cmos

Audit of everything configured in `~/nixos/` for host `cmos` that needs to be replicated in `~/arch/`.

Status key: DONE = already in ~/arch, TODO = needs migration, SKIP = not applicable/not wanted, PARTIAL = partially done

---

## 1. Packages

### 1.1 Missing Official Packages (pacman)

These were in NixOS but are not in `packages/official.txt`:

| Package | NixOS Module | Purpose |
|---------|-------------|---------|
| `jq` | core/packages | JSON processor (used by many scripts) |
| `htop` | core/packages | Process viewer |
| `tree` | core/packages | Directory listing |
| `ncdu` | core/packages | Disk usage analyzer |
| `lsof` | core/packages | List open files |
| `nmap` | core/packages | Network scanner |
| `bind` (dig) | core/packages | DNS lookup tools |
| `whois` | core/packages | Domain info |
| `aria2` | core/packages | Download accelerator |
| `dos2unix` | core/packages | Line ending converter |
| `wl-clipboard` | core/packages | Wayland clipboard (wl-copy/wl-paste) |
| `shellcheck` | core/packages | Shell script linter |
| `tldr` | core/packages | Simplified man pages |
| `parted` | core/packages | Disk partitioning |
| `usbutils` | core/packages | lsusb |
| `ffmpeg` | core/packages | Media processing |
| `mediainfo` | core/packages | Media file info |
| `mkvtoolnix-cli` | core/packages | MKV manipulation |
| `iotop` | core/packages | I/O monitor |
| `cpulimit` | core/packages | CPU throttle |
| `pandoc` | core/packages | Document converter |
| `poppler` (pdftotext etc) | core/packages | PDF tools |
| `ghostscript` | core/packages | PostScript/PDF |
| `qpdf` | core/packages | PDF manipulation |
| `tesseract` | core/packages | OCR engine |
| `rclone` | core/packages | Cloud storage sync |
| `openssl` | core/packages | Crypto toolkit |
| `git-filter-repo` | core/packages | Git history rewriting |
| `glow` | core/packages | Markdown renderer |
| `p7zip` | core/packages | 7z compression |
| `docker` | core/docker | Container runtime |
| `docker-compose` | core/docker | Multi-container orchestration |
| `docker-buildx` | core/docker | Docker build plugin |
| `v4l-utils` | host/cmos | Webcam config (v4l2-ctl) |
| `android-tools` | host/cmos | ADB for Android dev |
| `kate` | desktop/kde | KDE text editor |
| `imagemagick` | desktop/packages | Image manipulation |
| `yt-dlp` | desktop/packages | Video downloader |
| `ddcutil` | desktop/packages | Monitor DDC/CI control |
| `kitty` | desktop/terminals | GPU-accelerated terminal |
| `virt-manager` | desktop/vms | VM management GUI |
| `qemu-full` | desktop/vms | VM hypervisor |
| `libvirt` | desktop/vms | VM abstraction layer |
| `swtpm` | desktop/vms | Software TPM for VMs |
| `cmake` | core/dev/tools | Build system |
| `gcc` | core/dev/tools | C/C++ compiler |
| `pkg-config` | core/dev/tools | Build tool |
| `rust-analyzer` | core/dev/tools | Rust LSP |
| `lua` | desktop/packages | Lua interpreter |
| `xdotool` | desktop/packages | X11 automation |
| `wmctrl` | desktop/packages | Window management |
| `flatpak` | desktop/flatpak | Flatpak support |
| `cockpit` | core/cockpit | Web system management |
| `lynis` | security/scanning | Security auditing |
| `rustscan` | security/scanning | Fast port scanner |
| `fail2ban` | services/fail2ban-ssh | Intrusion prevention |
| `steam` | desktop/gaming | Gaming platform |
| `heroic-games-launcher-bin` | desktop/gaming | Epic/GOG launcher |
| `mangohud` | desktop/gaming | FPS overlay |
| `sunshine` | desktop/gaming | Game streaming server |
| `moonlight-qt` | desktop/gaming | Game streaming client |
| `jellyfin-media-player` | desktop/packages | Media player |
| `nextcloud-client` | desktop/packages | File sync |
| `radeontop` | desktop/ai/core | GPU usage monitor |
| `clinfo` | desktop/ai/core | OpenCL info |
| `pciutils` | desktop/amd-gpu | lspci |
| `tailscale` | desktop/packages | VPN |

### 1.2 Missing AUR Packages

| Package | NixOS Module | Purpose |
|---------|-------------|---------|
| `vesktop-bin` | desktop/discord | Discord client (Vencord, Wayland-native) |
| `wowup-cf` | desktop/gaming | WoW addon manager |
| `heroic-games-launcher-bin` | desktop/gaming | Epic/GOG (check if AUR) |
| `webcamoid` | desktop/packages | Webcam app |
| `fooyin` | desktop/packages | Music player |
| `devilutionx` | desktop/packages | Diablo port |
| `droidcam` | desktop/packages | Phone as webcam |
| `woeusb-ng` | desktop/packages | Windows USB creator |
| `google-cloud-cli` | desktop/packages | GCP/Firebase tools |

### 1.3 Python Packages Needed

NixOS had several Python environments. Key packages:
- `requests`, `flask`, `beautifulsoup4`, `selenium`, `aiohttp`, `pydantic` (dev/tools)
- `fastapi`, `uvicorn`, `sqlalchemy`, `python-multipart`, `bcrypt` (investment-tracker)
- `firebase-admin`, `google-api-python-client`, `google-auth-oauthlib` (various services)
- `rich` (timer-cli, google-tasks-tui)
- `evdev` (mouse-remap)
- `PyTorch ROCm` (AI/ML stack)

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

### 2.4 Missing FZF Utilities - TODO

From `modules/core/dev/fzf.nix`:

| Function | Purpose |
|----------|---------|
| `fnano` | Find file + search + open in nano |
| `fcd` | Navigate to directory with fzf |
| `fcat` | View file contents with preview |
| `fgrep` | Search + edit matches |
| `fobsi` | Search Obsidian vault |

### 2.5 Missing Git Commands - TODO

From `modules/core/dev/git.nix`:

| Command | Purpose |
|---------|---------|
| `gissue` | Create GitHub issues with AI-generated titles |
| `gpush` | Smart multi-repo push workflow |
| `gscan` | Secret scanning via trufflehog |
| `create-repo` | Create new GitHub repo |
| `ghelp` | Git command reference |
| `repo` | Toggle repo visibility (public/private) |

---

## 3. Systemd Services

### 3.1 Docker - TODO

NixOS config:
- Docker daemon with overlay2 storage, experimental features
- Docker Compose + buildx
- nicholas in docker group
- /opt/docker-compose directory

### 3.2 Cockpit - TODO

- Port 9090, web-based system management
- 4-hour session timeout
- CORS origins for LAN access
- Cyclic dependency fixes for systemd

### 3.3 Fail2ban SSH - TODO

- sshd jail: 5 retries in 10min = 1h ban
- sshd-flood jail: 10 retries in 1min = 3h ban
- LAN whitelist (192.168.1.0/24)
- Commands: `fail2ban-ssh-status`, `fail2ban-ssh-unban`

### 3.4 Samba - TODO

- Share cmos home directory on LAN
- SMB2/3 only, no guest, encrypted passwords
- nicholas samba user with password from secrets

### 3.5 Borg Backup - TODO (High Priority)

NixOS had an automated borg backup system:
- **Daily 5 AM**: Local backup to /mnt/data/backups/cmos/borg
- **Daily 5 AM**: Remote backup to nicholas@offsite.bedrosn.com
- Encryption: repokey-blake2 with passphrase
- Compression: zstd level 3
- Retention: 14 daily
- Paths: /etc, ~/.bash_history, ~/.config (KDE), ~/.ssh, ~/.claude, ~/.local/share/diet-db, Desktop, Documents, git, Pictures, Videos, /root/.gnupg/.ssh
- Excludes: node_modules, .venv, __pycache__, build, dist, target, .next
- Manual commands: `backup-cmos-manual-borg`, `backup-cmos-manual-borg-dry`

Packages needed: `borg`

### 3.6 Nextcloud Backup - TODO

- Nightly 4 AM: Sync Nextcloud data to Google Drive via rclone
- Script: backup-nextcloud.py
- Timeout: 30 minutes

### 3.7 Libvirt/KVM Virtualization - TODO

- libvirtd service with swtpm (TPM emulation)
- nicholas in libvirtd, kvm, render groups
- VM: nixvm (6GB RAM, 4 vCPUs, UEFI+SecureBoot, VirtIO, SPICE+GL)
- Disk: /mnt/data/vm/nixvm/nixvm.qcow2 (60GB)
- Management commands: vm-viewer, vm-list, vm-start, vm-stop, vm-kill, vm-restart, vm-info, vm-purge, vm-create
- nixvm-menu KDE dialog

### 3.8 Webcam C920 Config - TODO

- Systemd service to set MJPEG 1080p@30fps on boot
- Webcamoid scaled desktop entry (1.5x for HiDPI)

### 3.9 Mouse Button Remap (Razer Viper Mini) - TODO

- Python evdev script
- BTN_EXTRA: tap = original, hold = Left Control
- Systemd service: mouse-tap-hold
- Kernel module: uinput

### 3.10 USB Hub Bluetooth Toggle - TODO

- Udev rules for VIA Labs USB 2.0 Hub (2109:2817)
- Auto disable BT on hub disconnect, re-enable on reconnect
- Two systemd oneshot services

### 3.11 Screen Off + DND (Meta+F10) - TODO

- KWin script for Meta+F10 shortcut
- Toggles screen off via powerdevil
- Toggles KDE Do Not Disturb mode
- Watcher service to restore on wake

### 3.12 Bluetooth Toggle (Meta+F11) - TODO

- KWin script for Meta+F11 shortcut
- bt-toggle: power on/off + auto-connect Q30

### 3.13 ChatGPT Quick Input (Meta+F12) - TODO

- GTK4/libadwaita popup for text input
- Routes to dedicated Brave CDP window (port 9222)
- Injects text via Chrome DevTools Protocol
- KWin script for Meta+F12

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
