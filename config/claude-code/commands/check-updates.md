---
description: Check for available pacman and AUR updates and assess risk
allowed-tools: Bash(checkupdates:*), Bash(paru -Qua:*)
---

## Instructions

1. Run `checkupdates` and `paru -Qua` in parallel to get available pacman and AUR updates
2. Do NOT run the actual updates -- this is read-only

## Analysis

Provide a short summary with counts (pacman and AUR), then a risk assessment covering:

- **Kernel**: note version change, whether it requires reboot
- **GPU/Mesa/ROCm**: relevant to AMD RX 6800 XT and ollama-rocm
- **Desktop (KDE Plasma/KWin/KF6)**: note if major or minor release
- **Security-relevant**: openssl, openssh, cryptsetup, libcbor (FIDO2), python-cryptography, etc.
- **Notable version jumps**: major version bumps in libraries or tools that could break things
- **Bulk noise**: identify rebuild batches (haskell, qemu, vlc, etc.) that are just pkgrel bumps with no real change
- **AUR highlights**: anything notable in the AUR list

End with a one-line bottom-line verdict: low/medium/high risk, and whether it is safe to run.

Keep the output concise. Do not list every package -- group and summarize.
