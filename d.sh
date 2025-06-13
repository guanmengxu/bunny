#!/usr/bin/env bash
set -euo pipefail

# Usage: bash d.sh <base_or_path> [-e [script_args...]]
if [ $# -lt 1 ]; then
  echo "Usage: $0 <base_or_path> [-e [script_args...]]"
  exit 1
fi

# ─── 1) 拆分 target（支持带路径或仅 basename） ───
TARGET="$1"; shift
if [[ "$TARGET" == */* ]]; then
  # 用户传了路径，比如 /root/i 或 /root/i.sh
  if [[ "$TARGET" == *.sh ]]; then
    OUTPUT_PATH="$TARGET"
  else
    OUTPUT_PATH="${TARGET}.sh"
  fi
  BASE_NAME="$(basename "$OUTPUT_PATH" .sh)"
else
  # 纯 basename，比如 i
  BASE_NAME="$TARGET"
  OUTPUT_PATH="./${BASE_NAME}.sh"
fi

# ─── 2) 解析 -e 执行标志及脚本参数 ───
EXEC=false
SCRIPT_ARGS=()
if [ $# -gt 0 ]; then
  if [ "$1" = "-e" ]; then
    EXEC=true
    shift
    SCRIPT_ARGS=("$@")
  else
    echo "[!] Unknown option: $1"
    echo "    Only supported flag is -e (after target) to execute."
    exit 1
  fi
fi

# ─── 3) 原脚本：提示口令、检测 OS、安装 gnupg ───
read -s -p "[*] Enter passphrase for ${BASE_NAME}.gpg: " PASSPHRASE
echo

echo "[*] Checking OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID; OS_VERSION_ID=$VERSION_ID
else
    echo "[!] Cannot detect OS type. /etc/os-release not found."
    exit 1
fi
echo "[*] Detected OS: $OS_ID $OS_VERSION_ID"

if ! command -v gpg >/dev/null 2>&1; then
  echo "[*] gnupg not found, installing..."
  case "$OS_ID" in
    ubuntu|debian)   apt update && apt install -y gnupg ;;
    centos|rhel)    yum install -y gnupg ;;
    almalinux|rocky) dnf install -y gnupg ;;
    *)
      echo "[!] Unsupported OS: $OS_ID"
      exit 1
      ;;
  esac
else
  echo "[+] gnupg is already installed, skipping."
fi

# ─── 4) 下载并解密 ───
URL="https://raw.githubusercontent.com/guanmengxu/bunny/main/${BASE_NAME}.gpg"
TEMP_FILE="$(mktemp -t ${BASE_NAME}_XXXXXX.gpg)"

echo "[*] Downloading ${BASE_NAME}.gpg from GitHub..."
curl -sSL "$URL" -o "$TEMP_FILE" || {
  echo "[!] Download failed: $URL"
  rm -f "$TEMP_FILE"
  exit 1
}

if echo "$PASSPHRASE" | gpg --batch --yes --no-tty --no-use-agent \
     --passphrase-fd 0 -o "$OUTPUT_PATH" -d "$TEMP_FILE"; then
  chmod +x "$OUTPUT_PATH"
  echo "[+] Decryption succeeded: $OUTPUT_PATH"
else
  echo "[!] Decryption failed"
  rm -f "$TEMP_FILE"
  exit 1
fi

# Cleanup
rm -f "$TEMP_FILE"
gpgconf --reload gpg-agent
gpgconf --kill gpg-agent
gpg-connect-agent reloadagent /bye
gpg-connect-agent killagent /bye
pkill gpg-agent || true
killall gpg-agent || true

# ─── 6) 新增：如带 -e，则执行解密后的脚本 ───
if [ "$EXEC" = true ]; then
  if [ ${#SCRIPT_ARGS[@]} -gt 0 ]; then
    echo "[*] Executing $OUTPUT_PATH with args: ${SCRIPT_ARGS[*]}"
    bash "$OUTPUT_PATH" "${SCRIPT_ARGS[@]}"
  else
    echo "[*] Executing $OUTPUT_PATH"
    bash "$OUTPUT_PATH"
  fi
else
  echo "[*] Decryption only; to run it add -e:"
fi
