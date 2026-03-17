# Deferred Scheduled Tasks

All of these except Lynis require Discord webhook secrets (migration 9.1).

Reference: NixOS source files in `~/nixos/modules/` and `~/nixos/scripts/`.

## 4.1 CurseForge Comment Notifier

Scrapes CurseForge addon comment pages with Selenium/Firefox headless. Posts new comments to a Discord webhook. Runs at 08:00 and 19:00 daily. Tracks state in /var/lib/curseforge-comments.

Dependencies: selenium, firefox, geckodriver, Discord webhook secret.
NixOS ref: `~/nixos/scripts/curseforge-comments.py`, related module in `~/nixos/modules/`.

## 4.2 Upstream Issue Monitor

Checks specific GitHub issues for fix signals (e.g. Ollama flash attention on gfx1030). Posts to Discord webhook at 09:00 and 21:00 daily. Uses Claude Agent SDK to analyze issue threads.

Dependencies: Claude Agent SDK, GitHub PAT secret, Discord webhook secret.
NixOS ref: `~/nixos/scripts/check-upstream-issues.py`, `~/nixos/scripts/security_monitor_base.py`.

## 4.3 Discord Failure Notify Template

Reusable systemd template service. Attach to any service via `OnFailure=discord-failure-notify@%n.service`. On failure, reads last 20 journal lines and posts to Discord webhook.

Dependencies: Discord webhook secret, curl.
NixOS ref: search for "discord-failure" or "OnFailure" in `~/nixos/modules/`.

## 4.4 Update Notification

NixOS sent Discord notifications on rebuild with a package diff. Arch equivalent would hook into `pacman -Syu` (e.g. via pacman hook or post-transaction script) and notify with what packages changed.

Dependencies: Discord webhook secret. Needs design for Arch (pacman hook vs. wrapper script).
NixOS ref: search for "discord-webhook-rebuilds" in `~/nixos/modules/`.

## 4.5 Lynis Security Audit

Monthly automated security scan. Reports saved to /var/log/security-scans/lynis. Custom profile that skips desktop-irrelevant checks. Self-contained - no secrets needed.

Dependencies: lynis (already installed), systemd timer.
NixOS ref: search for "lynis" in `~/nixos/modules/`.
