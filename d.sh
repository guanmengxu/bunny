#!/usr/bin/env bash
set -euo pipefail

# Usage: bash di.sh <base_name> [output_path]
if [ $# -lt 1 ]; then
  echo "Usage: $0 <base_name> [output_path]"
  exit 1
fi

BASE_NAME="$1"
OUTPUT_PATH="${2:-./${BASE_NAME}.sh}"
# if the user passed a directory, append the filename
if [ -n "${2-}" ] && [ -d "$OUTPUT_PATH" ]; then
  OUTPUT_PATH="${OUTPUT_PATH%/}/${BASE_NAME}.sh"
fi

# Prompt for passphrase first
read -s -p "[*] Enter passphrase for ${BASE_NAME}.gpg: " PASSPHRASE
echo

# Detect OS Type
echo "[*] Checking OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION_ID=$VERSION_ID
else
    echo "[!] Cannot detect OS type. /etc/os-release not found."
    exit 1
fi

echo "[*] Detected OS: $OS_ID $OS_VERSION_ID"

# Install gnupg only if not already installed
if ! command -v gpg >/dev/null 2>&1; then
  echo "[*] gnupg not found, installing..."
  case "$OS_ID" in
      ubuntu|debian)
          apt update && apt install -y gnupg
          ;;
      centos|rhel)
          yum install -y gnupg
          ;;
      almalinux|rocky)
          dnf install -y gnupg
          ;;
      *)
          echo "[!] Unsupported OS: $OS_ID"
          exit 1
          ;;
  esac
else
  echo "[+] gnupg is already installed, skipping install."
fi

# Prepare download URL and temp file
URL="https://raw.githubusercontent.com/guanmengxu/bunny/main/${BASE_NAME}.gpg"
TEMP_FILE="$(mktemp -t ${BASE_NAME}_XXXXXX.gpg)"

echo "[*] Downloading ${BASE_NAME}.gpg from GitHub..."
curl -sSL "$URL" -o "$TEMP_FILE" || {
  echo "[!] Download failed: $URL"
  rm -f "$TEMP_FILE"
  exit 1
}

# Decrypt and write output
if echo "$PASSPHRASE" | gpg --batch --yes --no-tty --no-use-agent \
    --passphrase-fd 0 -o "$OUTPUT_PATH" -d "$TEMP_FILE"; then
  chmod +x "$OUTPUT_PATH"
  echo "[+] Decryption succeeded: $OUTPUT_PATH"
  echo "[>] Run it with: bash $OUTPUT_PATH"
else
  echo "[!] Decryption failed"
  rm -f "$TEMP_FILE"
  exit 1
fi

# Cleanup
rm -f "$TEMP_FILE"
gpgconf --reload gpg-agent
gpgconf --kill gpg-agent
