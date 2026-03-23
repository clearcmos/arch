#!/bin/bash
# Sync configuration drift between repo and deployed copies.
# For each drifted file, offers to view the diff and pull changes back to the repo.
#
# Usage:
#   check-drift          # interactive mode
#   check-drift --check  # report only, no prompts (for scripts/CI)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

drifted=0
synced=0
checked=0

check() {
    local src="$1" dst="$2"
    [[ -f "$dst" ]] || return 0
    checked=$((checked + 1))
    if diff -q "$src" "$dst" &>/dev/null; then
        return 0
    fi
    drifted=$((drifted + 1))

    if $CHECK_ONLY; then
        echo -e "\033[1;33m[DRIFT]\033[0m $dst"
        return 0
    fi

    while true; do
        echo -e "\033[1;33m[DRIFT]\033[0m $dst"
        read -r -p "  [ENTER/r]epo <- live / [d]iff / [c]laude explain / [l]ive <- repo / [s]kip? " choice < /dev/tty
        case "$choice" in
            d)
                local tmp
                tmp=$(mktemp)
                diff --color=always --side-by-side --left-column \
                    --label "REPO: $(basename "$src")" \
                    --label "LIVE: $dst" \
                    "$src" "$dst" > "$tmp" || true
                less -R "$tmp" < /dev/tty
                rm -f "$tmp"
                ;;
            c)
                local udiff tmp_diff
                udiff=$(diff -u "$src" "$dst" || true)
                tmp_diff=$(mktemp)
                echo "$udiff" > "$tmp_diff"
                echo ""
                local explanation
                explanation=$(claude --print \
                    --model sonnet \
                    -p "Explain this config drift in plain language. The left side (---) is my repo version (source of truth), the right side (+++) is the live system version. Tell me: what changed, why it likely changed (e.g. app settings GUI, package update, manual edit), and whether I should pull it into my repo or push my repo version to restore it. Be concise.

$(cat "$tmp_diff")")
                if command -v glow &>/dev/null; then
                    echo "$explanation" | glow -
                else
                    echo "$explanation"
                fi
                rm -f "$tmp_diff"
                echo ""
                ;;
            ""|r)
                if [[ "$dst" == /etc/* ]]; then
                    sudo cp "$dst" "$src"
                else
                    cp "$dst" "$src"
                fi
                synced=$((synced + 1))
                echo "  Updated repo from live."
                break
                ;;
            l)
                if [[ "$dst" == /etc/* ]]; then
                    sudo cp "$src" "$dst"
                else
                    cp "$src" "$dst"
                fi
                synced=$((synced + 1))
                echo "  Updated live from repo."
                break
                ;;
            s)
                break
                ;;
            *)
                echo "  Invalid choice."
                ;;
        esac
    done
}

echo "Checking for configuration drift..."
echo ""

# KDE configs (copied because KConfig atomic writes break symlinks)
check "$REPO_DIR/config/kde/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
check "$REPO_DIR/config/kde/plasmashellrc" "$HOME/.config/plasmashellrc"
check "$REPO_DIR/config/kde/powerdevilrc" "$HOME/.config/powerdevilrc"
check "$REPO_DIR/config/kde/ksmserverrc" "$HOME/.config/ksmserverrc"
check "$REPO_DIR/config/kde/kwinoutputconfig.json" "$HOME/.config/kwinoutputconfig.json"
check "$REPO_DIR/config/kde/kcminputrc" "$HOME/.config/kcminputrc"

# User systemd services (copied)
check "$REPO_DIR/config/xremap/xremap.service" "$HOME/.config/systemd/user/xremap.service"
check "$REPO_DIR/config/systemd/user/screen-off-toggle.service" "$HOME/.config/systemd/user/screen-off-toggle.service"
check "$REPO_DIR/config/systemd/user/screen-off-watcher.service" "$HOME/.config/systemd/user/screen-off-watcher.service"
check "$REPO_DIR/config/systemd/user/bt-toggle.service" "$HOME/.config/systemd/user/bt-toggle.service"

# SSH (copied)
check "$REPO_DIR/config/ssh/authorized_keys" "$HOME/.ssh/authorized_keys"

# System configs under /etc/ (copied, require root)
check "$REPO_DIR/config/fontconfig/local.conf" "/etc/fonts/local.conf"
check "$REPO_DIR/config/ssh/sshd_config" "/etc/ssh/sshd_config"
check "$REPO_DIR/config/bluetooth/main.conf" "/etc/bluetooth/main.conf"
check "$REPO_DIR/config/brave/policies/policies.json" "/etc/brave/policies/managed/policies.json"
check "$REPO_DIR/config/greetd/config.toml" "/etc/greetd/config.toml"
check "$REPO_DIR/config/greetd/pam-greetd" "/etc/pam.d/greetd"
check "$REPO_DIR/config/pacman/check-upgrades.hook" "/etc/pacman.d/hooks/check-upgrades.hook"
check "$REPO_DIR/config/sysctl/99-quiet-console.conf" "/etc/sysctl.d/99-quiet-console.conf"
check "$REPO_DIR/config/sysctl/99-hardening.conf" "/etc/sysctl.d/99-hardening.conf"
check "$REPO_DIR/config/security/faillock.conf" "/etc/security/faillock.conf"
check "$REPO_DIR/config/modules-load/i2c-dev.conf" "/etc/modules-load.d/i2c-dev.conf"
check "$REPO_DIR/config/fail2ban/jail.local" "/etc/fail2ban/jail.local"
check "$REPO_DIR/config/nftables/nftables.conf" "/etc/nftables.conf"
check "$REPO_DIR/config/docker/daemon.json" "/etc/docker/daemon.json"
check "$REPO_DIR/config/cups/cupsd.conf" "/etc/cups/cupsd.conf"
check "$REPO_DIR/config/cockpit/cockpit.conf" "/etc/cockpit/cockpit.conf"
check "$REPO_DIR/config/udev/99-usb-hub-bt-toggle.rules" "/etc/udev/rules.d/99-usb-hub-bt-toggle.rules"
check "$REPO_DIR/config/systemd/usb-hub-bt-off.service" "/etc/systemd/system/usb-hub-bt-off.service"
check "$REPO_DIR/config/systemd/usb-hub-bt-on.service" "/etc/systemd/system/usb-hub-bt-on.service"
check "$REPO_DIR/config/udev/99-xremap.rules" "/etc/udev/rules.d/99-xremap.rules"

# Summary
echo ""
echo "---"
echo "Checked $checked files, $drifted drifted, $synced synced."
