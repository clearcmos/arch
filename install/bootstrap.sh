#!/bin/bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/clearcmos/arch/main/install"

mkdir -p /root/arch/install
curl -sL "$REPO/user_configuration.json" -o /root/arch/install/user_configuration.json
curl -sL "$REPO/install.sh" -o /root/arch/install/install.sh
chmod +x /root/arch/install/install.sh
/root/arch/install/install.sh
