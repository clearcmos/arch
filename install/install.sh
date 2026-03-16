#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/user_configuration.json"
CREDS="/tmp/user_credentials.json"

# --- Password input ---

read_password() {
    local label="$1" pw pw2
    while true; do
        read -rsp "Enter $label password: " pw; echo
        read -rsp "Confirm $label password: " pw2; echo
        if [[ "$pw" == "$pw2" ]]; then
            echo "$pw"
            return
        fi
        echo "Passwords do not match. Try again."
    done
}

# --- Yescrypt hashing via Python (matches archinstall's own method) ---

hash_password() {
    local pw="$1"
    python3 -c "
import ctypes, ctypes.util
lib = ctypes.CDLL(ctypes.util.find_library('crypt'))
lib.crypt.restype = ctypes.c_char_p
lib.crypt_gensalt.restype = ctypes.c_char_p
salt = lib.crypt_gensalt(b'\$y\$', 0, None, 0)
print(lib.crypt(b'''$pw''', salt).decode())
"
}

echo "=== Arch Install ==="
echo

root_pw=$(read_password "root")
user_pw=$(read_password "nicholas")

echo
echo "Hashing passwords..."
root_hash=$(hash_password "$root_pw")
user_hash=$(hash_password "$user_pw")

# --- Write temporary credentials ---

cat > "$CREDS" <<EOF
{
    "root_enc_password": "$root_hash",
    "users": [
        {
            "username": "nicholas",
            "enc_password": "$user_hash",
            "sudo": true
        }
    ]
}
EOF

echo "Credentials written to $CREDS (will be lost on reboot)."
echo
echo "Starting archinstall..."
archinstall --config "$CONFIG" --creds "$CREDS"
