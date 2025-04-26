#!/usr/bin/env bash
set -euo pipefail

# Usage: bash di.sh <base_name> [output_path]
if [ $# -lt 1 ]; then
  echo "Usage: $0 <base_name> [output_path]"
  exit 1
fi

BASE_NAME="$1"
OUTPUT_PATH="${2:-./${BASE_NAME}.sh}"
URL="https://raw.githubusercontent.com/guanmengxu/bunny/main/${BASE_NAME}.gpg"
TEMP_FILE="$(mktemp -t ${BASE_NAME}_XXXXXX.gpg)"

echo "[*] Downloading ${BASE_NAME}.gpg from GitHub..."
curl -sSL "$URL" -o "$TEMP_FILE" || {
  echo "[!] Download failed: $URL"
  rm -f "$TEMP_FILE"
  exit 1
}

read -s -p "[*] Enter passphrase for ${BASE_NAME}.gpg: " PASSPHRASE
echo

if echo "$PASSPHRASE" | gpg --batch --yes --no-tty --pinentry-mode loopback \
    --passphrase-fd 0 -o "$OUTPUT_PATH" -d "$TEMP_FILE"; then
  chmod +x "$OUTPUT_PATH"
  echo "[+] Decryption succeeded: $OUTPUT_PATH"
  echo "[>] Run it with: bash $OUTPUT_PATH"
else
  echo "[!] Decryption failed"
  rm -f "$TEMP_FILE"
  exit 1
fi

rm -f "$TEMP_FILE"
gpgconf --reload gpg-agent
gpgconf --kill gpg-agent
