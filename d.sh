#!/usr/bin/env bash
set -euo pipefail

# Usage: bash d.sh <base_name> [-e|--exec] [script_args...]
if [ $# -lt 1 ]; then
  echo "Usage: $0 <base_name> [-e|--exec] [script_args...]"
  exit 1
fi

BASE_NAME="$1"
shift

# ─── 新增：解析 -e/--exec 标志和脚本参数 ───
EXEC=false
SCRIPT_ARGS=()
if [ $# -gt 0 ]; then
  case "$1" in
    -e|--exec)
      EXEC=true
      shift
      SCRIPT_ARGS=("$@")
      ;;
    *)
      echo "[!] Unknown option: $1"
      echo "    Only supported flag is -e|--exec"
      exit 1
      ;;
  esac
fi

OUTPUT_PATH="./${BASE_NAME}.sh"
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

# Decrypt and write output (原功能：下载→解密→写文件)
if echo "$PASSPHRASE" | gpg --batch --yes --no-tty --no-use-agent \
    --passphrase-fd 0 -o "$OUTPUT_PATH" -d "$TEMP_FILE"; then
  chmod +x "$OUTPUT_PATH"
  echo "[+] Decryption succeeded: $OUTPUT_PATH"
else
  echo "[!] Decryption failed"
  rm -f "$TEMP_FILE"
  exit 1
fi

# Cleanup (原功能)
rm -f "$TEMP_FILE"
gpgconf --reload gpg-agent
gpgconf --kill gpg-agent
gpg-connect-agent reloadagent /bye
gpg-connect-agent killagent /bye
pkill gpg-agent || true
killall gpg-agent || true

# ─── 新增：根据 -e 标志决定是否执行解密后的脚本 ───
if [ "$EXEC" = true ]; then
  if [ ${#SCRIPT_ARGS[@]} -gt 0 ]; then
    echo "[*] Executing decrypted script with args: ${SCRIPT_ARGS[*]}"
    bash "$OUTPUT_PATH" "${SCRIPT_ARGS[@]}"
  else
    echo "[*] Executing decrypted script (no args)..."
    bash "$OUTPUT_PATH"
  fi
else
  echo "[*] Decryption only; use -e to execute."
fi
